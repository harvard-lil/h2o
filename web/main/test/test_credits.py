from django.urls import reverse

from main.models import Casebook


def test_credits_no_parent(full_casebook, client):
    """The credits page should be displayed for a casebook that was directly authored"""
    resp = client.get(reverse("show_credits", args=[full_casebook]))
    assert resp.status_code == 200
    assert len(resp.context["contributing_casebooks"]) == 0


def test_credits_parent(full_casebook, client):
    """The credits page should indicate that a cloned casebook has a parent"""
    clone = full_casebook.clone(current_user=full_casebook.testing_editor)
    client.post(reverse("publish", args=[clone]), as_user=full_casebook.testing_editor)
    resp = client.get(reverse("show_credits", args=[clone]))
    assert len(resp.context["contributing_casebooks"]) == 1
    assert full_casebook == resp.context["contributing_casebooks"][0]["casebook"]

    # Show the nodes for the parent casebook
    assert full_casebook.children.first().id in [
        n[1].id for n in resp.context["contributing_casebooks"][0]["nodes"]
    ]


def test_credits_ancestors(full_casebook, user_factory, client):
    """The credits page should indicate that a cloned casebook has previous ancestors"""
    other_user = user_factory()
    clone = full_casebook.clone(current_user=other_user)
    client.post(reverse("publish", args=[clone]), as_user=other_user)

    clone_of_clone = clone.clone(current_user=full_casebook.testing_editor)
    client.post(reverse("publish", args=[clone_of_clone]), as_user=full_casebook.testing_editor)

    resp = client.get(reverse("show_credits", args=[clone_of_clone]))
    assert len(resp.context["contributing_casebooks"]) == 1
    assert len(resp.context["contributing_casebooks"][0]["incidental_authors"]) == 1


def test_credits_omit_drafts(full_casebook, client):
    """The credits page should canonicalize revised ancestors to their published drafts"""
    grandparent = full_casebook
    parent = full_casebook.clone(current_user=full_casebook.testing_editor)
    assert parent.state != Casebook.LifeCycle.PUBLISHED.value
    child = parent.clone(current_user=full_casebook.testing_editor)
    client.post(reverse("publish", args=[child]), as_user=full_casebook.testing_editor)
    resp = client.get(reverse("show_credits", args=[child]))
    assert len(resp.context["contributing_casebooks"]) == 1

    # If the immediate parent is a draft, we should only show the grandparent as a contributor
    assert resp.context["contributing_casebooks"][0]["casebook"].id == grandparent.id

    # Publish the draft and now this should be the direct parent
    client.post(reverse("publish", args=[parent]), as_user=full_casebook.testing_editor)

    resp = client.get(reverse("show_credits", args=[child]))
    assert resp.context["contributing_casebooks"][0]["casebook"].id == parent.id


def test_credits_omit_private(full_casebook_parts_with_prof_only_resource, client):
    """The credits page should omit listing sections that are professor-only if the user cannot see them"""
    casebook, *parts = full_casebook_parts_with_prof_only_resource
    assert parts[2].is_instructional_material

    clone = casebook.clone(current_user=casebook.testing_editor)
    client.post(reverse("publish", args=[clone]), as_user=casebook.testing_editor)

    resp = client.get(reverse("show_credits", args=[clone]))
    assert parts[0] in [n[1] for n in resp.context["contributing_casebooks"][0]["nodes"]]
    assert parts[2] not in [n[1] for n in resp.context["contributing_casebooks"][0]["nodes"]]

    # As the author, this instructional content is available
    resp = client.get(reverse("show_credits", args=[clone]), as_user=casebook.testing_editor)
    assert parts[2] in [n[1] for n in resp.context["contributing_casebooks"][0]["nodes"]]
