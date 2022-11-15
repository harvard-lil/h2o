import pytest
from test.test_helpers import check_response
from pytest_django.asserts import assertContains, assertNotContains, assertFormError


@pytest.fixture
def casebook_or_draft(request):
    """Given a fixture name that corresponds to a casebook, return the casebook's draft if present,
    or the casebook itself if not"""
    casebook = request.getfixturevalue(
        request.param
    )  # Interpret the indirect parameter as a fixture and then run the fixture function
    return casebook.draft if casebook.draft else casebook


@pytest.mark.parametrize(
    "casebook_or_draft", ["full_private_casebook", "full_casebook_with_draft"], indirect=True
)
@pytest.mark.parametrize(
    "resource_type,edit_field,edit_value",
    [
        ["TextBlock", "title", "owner-edited title"],
        ["LegalDocument", "title", "owner-edited title"],
    ],
)
def test_edit_resources(casebook_or_draft, resource_type, edit_field, edit_value, client):
    """Users should be able to edit resource metadata via a web form"""
    resource = casebook_or_draft.contents.filter(resource_type=resource_type).first()
    orig_value = getattr(resource, edit_field)
    check_response(
        client.get(resource.get_edit_url(), as_user=resource.testing_editor),
        content_includes=[orig_value],
    )
    resp = client.post(
        resource.get_edit_url(),
        {edit_field: edit_value},
        as_user=resource.testing_editor,
        follow=True,
    )
    assertContains(resp, edit_value)
    assertNotContains(resp, orig_value)


@pytest.mark.parametrize(
    "casebook_or_draft", ["full_private_casebook", "full_casebook_with_draft"], indirect=True
)
@pytest.mark.parametrize(
    "resource_type,edit_field,edit_value",
    [
        ["TextBlock", "content", "owner-edited content"],
        ["Link", "url", "http://new.example.com"],
    ],
)
def test_edit_subresource(casebook_or_draft, resource_type, edit_field, edit_value, client):
    """Users should be able to edit Link or TextBlock data"""
    resource = casebook_or_draft.contents.filter(resource_type=resource_type).first()
    orig_value = getattr(resource.resource, edit_field)
    edit_value = edit_value
    check_response(
        client.get(resource.get_edit_url(), as_user=resource.testing_editor),
        content_includes=[orig_value],
    )
    post_body = {"title": "Title"}
    post_body[edit_field] = edit_value
    resp = client.post(
        resource.get_edit_url(),
        post_body,
        as_user=resource.testing_editor,
        follow=True,
    )
    assertContains(resp, edit_value)
    assertNotContains(resp, orig_value)


def test_subresource_validation(full_private_casebook, client):
    """Passing invalid data to the subresource form should return a user-visible error"""
    resource = full_private_casebook.contents.filter(resource_type="Link").first()
    new_title = "New title"
    new_url = "http://new.example.com"

    # Ensure that the parent resource isn't modified if the subresource had a validation error
    resp = client.post(
        resource.get_edit_url(),
        {"url": "invalid", "title": new_title},
        as_user=resource.testing_editor,
        follow=True,
    )
    resource.refresh_from_db()
    assert resource.title != new_title
    assertFormError(resp, "embedded_resource_form", "url", "Enter a valid URL.")

    # Both forms must validate before any part of the resource can be saved
    resp = client.post(
        resource.get_edit_url(),
        {"url": new_url, "title": new_title},
        as_user=resource.testing_editor,
        follow=True,
    )
    resource.refresh_from_db()
    assert resource.title == new_title
    resource.resource.refresh_from_db()
    assert resource.resource.url == new_url
