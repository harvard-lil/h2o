import pytest
from django.urls import reverse
from playwright.sync_api import expect

from main.models import User


@pytest.mark.xdist_group("functional")
@pytest.mark.parametrize("kind", ["link", "text"])
def test_add_content_popup(
    static_live_server,
    page,
    login_as_default,
    private_casebook_factory,
    section_factory,
    mocker,
    kind,
):
    """The real browser must send multipart data and save a resource in the selected section."""
    user = User.objects.get(email_address="functional-test@example.edu")
    casebook = private_casebook_factory(contentcollaborator_set__user=user)
    section = section_factory(casebook=casebook, ordinals=[1])
    mocker.patch("main.views.get_link_title", return_value="Example document")
    page.goto(static_live_server.url + reverse("edit_section", args=[casebook, section]))
    page.get_by_role("button", name="Add Content", exact=True).click()
    modal = page.locator("#modal")
    if kind == "link":
        modal.get_by_text("Add Link", exact=True).click()
        modal.locator('[name="url"]').fill("https://example.com/document.pdf?api=v2")
    else:
        modal.get_by_text("Create Custom Content", exact=True).click()
        modal.locator('[name="name"]').fill("Example document")
        modal.locator(".tox-edit-area iframe").content_frame.locator("body").fill("Example body")
    endpoint = f"/casebooks/{casebook.id}/new/{kind}"
    with page.expect_response(
        lambda response: response.request.method == "POST" and response.url.endswith(endpoint)
    ) as saved:
        modal.get_by_role("button", name="Add", exact=True).click()
    assert saved.value.status == 302
    assert saved.value.request.headers["content-type"].startswith("multipart/form-data;")
    resource = section.contents.get()
    expect(page).to_have_url(static_live_server.url + resource.get_edit_url())
    assert resource.title == "Example document"
    assert resource.ordinals == [1, 1]
    if kind == "link":
        assert resource.resource.url == "https://example.com/document.pdf?api=v2"
    else:
        assert "Example body" in resource.resource.content
