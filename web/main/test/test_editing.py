import pytest
from test.test_helpers import check_response
from pytest_django.asserts import assertContains, assertNotContains


@pytest.fixture
def casebook_or_draft(request):
    """Return a casebook's draft if present, or the casebook itself"""
    casebook = request.getfixturevalue(request.param)
    return casebook.draft if casebook.draft else casebook


@pytest.mark.parametrize(
    "casebook_or_draft", ["full_private_casebook", "full_casebook_with_draft"], indirect=True
)
def test_edit_resources(casebook_or_draft, client):
    """Users should be able to edit resource metadata via a web form"""
    resource = casebook_or_draft.contents.first()
    orig_title = resource.title
    new_title = "owner-edited title"
    check_response(
        client.get(resource.get_edit_url(), as_user=resource.testing_editor),
        content_includes=[resource.title, "casebook-draft"],
    )
    resp = client.post(
        resource.get_edit_url(), {"title": new_title}, as_user=resource.testing_editor, follow=True
    )
    assertContains(resp, new_title)
    assertNotContains(resp, orig_title)
