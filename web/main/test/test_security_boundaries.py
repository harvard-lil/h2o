import pytest
from django.urls import reverse


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_annotation_cross_resource(private_annotation, private_casebook, resource_factory, method):
    from django.test import Client

    client = Client(enforce_csrf_checks=True)
    client.force_login(private_casebook.testing_editor)
    client.get(private_casebook.get_edit_url())
    owned = resource_factory(casebook=private_casebook)
    victim = private_annotation
    assert not victim.resource.casebook.editable_by(private_casebook.testing_editor)
    url = reverse("annotation_detail", args=[owned, victim])
    response = getattr(client, method)(
        url,
        {"annotation": {"content": "Synthetic unauthorized change"}},
        content_type="application/json",
        HTTP_X_CSRF_TOKEN=client.cookies["csrftoken"].value,
    )
    assert response.status_code == 404
    victim.refresh_from_db()
    assert victim.content != "Synthetic unauthorized change"


def test_bulk_headnote_is_sanitized(client, private_casebook):
    html = '<img src="/synthetic-missing-image" onerror="window.__h2oAudit = true">'
    response = client.post(
        reverse("new_from_outline", args=[private_casebook]),
        {"data": [{"title": "Synthetic section", "headnote": html}]},
        content_type="application/json",
        as_user=private_casebook.testing_editor,
    )
    assert response.status_code == 200
    assert "onerror=" not in private_casebook.contents.get().headnote


def test_clone_get_does_not_mutate(client, private_casebook, section):
    before = private_casebook.contents.count()
    url = reverse("clone_nodes", args=[section.casebook, section, private_casebook])
    # The response can fail after persistence; suppress propagation to inspect effects.
    client.raise_request_exception = False
    response = client.get(url, as_user=private_casebook.testing_editor)
    assert response.status_code == 405
    assert private_casebook.contents.count() == before


def test_restricted_resource_clone(client, private_casebook, resource_factory):
    source = resource_factory(is_instructional_material=True, resource_type="TextBlock")
    user = private_casebook.testing_editor
    user.verified_professor = False
    user.save()
    assert not source.viewable_by(user)
    response = client.post(
        reverse("new_from_outline", args=[private_casebook]),
        {
            "data": [
                {
                    "resource_type": "Clone",
                    "casebookId": str(source.casebook_id),
                    "resourceId": str(source.id),
                }
            ]
        },
        content_type="application/json",
        as_user=user,
    )
    assert response.status_code == 404
    assert not private_casebook.contents.exists()


def test_section_toc_omits_restricted_title(client, section, resource_factory):
    child = resource_factory(
        casebook=section.casebook,
        ordinals=[1, 1],
        is_instructional_material=True,
        title="Synthetic professor-only answer title",
    )
    response = client.get(reverse("toc_list", args=[section.casebook, section]))
    assert response.status_code == 200
    assert child.title.encode() not in response.content


def test_iframe_allowlist_rejects_other_host():
    from main.sanitize import sanitize

    html = '<iframe src="https://player-vimeo.com/video/123"></iframe>'
    assert "https://player-vimeo.com/video/123" not in sanitize(html)


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_annotation_csrf_and_ownership(private_annotation, method):
    from django.test import Client

    c = Client(enforce_csrf_checks=True)
    c.force_login(private_annotation.resource.testing_editor)
    c.get(private_annotation.resource.casebook.get_edit_url())
    url = reverse("annotation_detail", args=[private_annotation.resource, private_annotation])
    payload = {"annotation": {"content": "Allowed edit"}}
    assert getattr(c, method)(url, payload, content_type="application/json").status_code == 403
    response = getattr(c, method)(
        url,
        payload,
        content_type="application/json",
        HTTP_X_CSRF_TOKEN=c.cookies["csrftoken"].value,
    )
    assert response.status_code == (200 if method == "patch" else 204)


@pytest.mark.parametrize("bulk", [False, True])
def test_private_casebook_cannot_be_cloned(
    client, private_casebook, private_casebook_factory, bulk
):
    source = private_casebook_factory()
    if bulk:
        response = client.post(
            reverse("new_from_outline", args=[private_casebook]),
            {"data": [{"resource_type": "Clone", "casebookId": str(source.id)}]},
            content_type="application/json",
            as_user=private_casebook.testing_editor,
        )
    else:
        response = client.post(
            reverse("clone", args=[source]), as_user=private_casebook.testing_editor
        )
    assert response.status_code == 404


@pytest.mark.parametrize("verified", [False, True])
@pytest.mark.parametrize("route", ["book", "section", "bulk"])
def test_clone_visibility(
    client, casebook, private_casebook, section_factory, resource_factory, verified, route
):
    from main.models import Casebook

    user = private_casebook.testing_editor
    user.verified_professor = verified
    user.save()
    section = section_factory(casebook=casebook, ordinals=[1])
    resource_factory(
        casebook=casebook, ordinals=[1, 1], resource_type="TextBlock", title="Visible text"
    )
    resource_factory(
        casebook=casebook,
        ordinals=[1, 2],
        resource_type="TextBlock",
        title="Restricted text",
        is_instructional_material=True,
    )
    if route == "book":
        previous = set(Casebook.objects.values_list("id", flat=True))
        response = client.post(reverse("clone", args=[casebook]), as_user=user)
        destination = Casebook.objects.exclude(id__in=previous).get()
    elif route == "section":
        response = client.post(
            reverse("clone_nodes", args=[casebook, section, private_casebook]), as_user=user
        )
        destination = private_casebook
    else:
        response = client.post(
            reverse("new_from_outline", args=[private_casebook]),
            {"data": [{"resource_type": "Clone", "casebookId": str(casebook.id)}]},
            content_type="application/json",
            as_user=user,
        )
        destination = private_casebook
    assert response.status_code in (200, 302)
    assert destination.contents.filter(title="Visible text").exists()
    assert destination.contents.filter(title="Restricted text").exists() is verified
    assert b"Restricted text" not in response.content if not verified else True


def test_existing_restricted_clone_cannot_be_read_or_modified(
    client, private_casebook, resource_factory
):
    node = resource_factory(
        casebook=private_casebook,
        ordinals=[1],
        resource_type="TextBlock",
        is_instructional_material=True,
    )
    user = private_casebook.testing_editor
    user.verified_professor = False
    user.save()
    for endpoint in ["edit_resource", "annotate_resource"]:
        assert (
            client.get(reverse(endpoint, args=[private_casebook, node]), as_user=user).status_code
            == 403
        )
    assert (
        client.post(
            reverse("edit_resource", args=[private_casebook, node]),
            {"title": "New title", "content": "Changed", "is_instructional_material": False},
            as_user=user,
        ).status_code
        == 403
    )
    node.refresh_from_db()
    assert node.is_instructional_material


def test_hidden_ancestor_and_empty_section_scoping(
    casebook, section_factory, resource_factory, user
):
    empty = section_factory(casebook=casebook, ordinals=[1])
    section_factory(casebook=casebook, ordinals=[2], is_instructional_material=True)
    child = resource_factory(casebook=casebook, ordinals=[2, 1])
    assert not empty.contents_for_user(user).exists()
    assert list(casebook.nodes_for_user(user)) == [empty]
    assert not child.viewable_by(user)


@pytest.mark.parametrize(
    "endpoint,payload",
    [
        ("new_section", {"title": "Wrong parent"}),
        ("new_text", {"name": "Wrong parent", "content": "Text"}),
        ("new_link", {"url": "https://example.com", "name": "Wrong parent"}),
    ],
)
def test_other_casebook_parent_rejected(client, private_casebook, section, endpoint, payload):
    payload = {**payload, "section": section.id}
    assert (
        client.post(
            reverse(endpoint, args=[private_casebook]),
            payload,
            as_user=private_casebook.testing_editor,
        ).status_code
        == 404
    )
    assert not private_casebook.contents.exists()


def test_link_annotation_rejects_executable_url(client, private_annotation):
    node = private_annotation.resource
    response = client.post(
        reverse("annotation_list", args=[node]),
        {
            "annotation": {
                "kind": "link",
                "content": "javascript:alert(1)",
                "start_offset": 0,
                "end_offset": 1,
            }
        },
        content_type="application/json",
        as_user=node.testing_editor,
    )
    assert response.status_code == 400


@pytest.mark.parametrize("parent", ["bad", "-1", "0", "9" * 30])
def test_invalid_parent_returns_not_found(client, private_casebook, parent):
    response = client.post(
        reverse("new_section", args=[private_casebook]),
        {"title": "Invalid parent", "section": parent},
        as_user=private_casebook.testing_editor,
    )
    assert response.status_code == 404
    assert not private_casebook.contents.exists()


@pytest.mark.parametrize(
    "url,allowed",
    [
        ("https://www.youtube.com/embed/abc-_123?start=10", True),
        ("//player.vimeo.com/video/123?autoplay=0", True),
        ("https://www-youtube.com/embed/123", False),
        ("https://player.vimeo.com.evil.test/video/123", False),
        ("https://user@player.vimeo.com/video/123", False),
        ("https://player.vimeo.com:8000/video/123", False),
    ],
)
def test_embed_destinations(url, allowed):
    from main.sanitize import allowed_iframe_url

    assert allowed_iframe_url(url) is allowed


def test_draft_preserves_restricted_content(casebook, resource_factory):
    restricted = resource_factory(
        casebook=casebook, ordinals=[1], resource_type="TextBlock", is_instructional_material=True
    )
    draft = casebook.make_draft()
    copied = draft.contents.get()
    assert copied.is_instructional_material
    assert copied.provenance[-1] == restricted.id
    assert copied.resource.content == restricted.resource.content
