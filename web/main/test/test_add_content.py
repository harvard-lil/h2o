import pytest
from django.urls import reverse


@pytest.mark.parametrize("endpoint,required_field", [("new_link", "url"), ("new_text", "name")])
@pytest.mark.parametrize("content_type", ["application/json", "multipart/form-data"])
def test_empty_add_content_returns_field_errors(
    client, private_casebook, endpoint, required_field, content_type
):
    """An empty or wrongly encoded submission must not fail with an empty error object."""
    kwargs = {"content_type": content_type} if content_type == "application/json" else {}
    count = private_casebook.contents.count()
    response = client.post(
        reverse(endpoint, args=[private_casebook]),
        {},
        as_user=private_casebook.testing_editor,
        **kwargs,
    )
    assert response.status_code == 400
    assert response.json()[required_field][0]["code"] == "required"
    assert private_casebook.contents.count() == count


@pytest.mark.parametrize("name", ["", "User-supplied title"])
def test_link_title_does_not_invalidate_resource(client, private_casebook, mocker, name):
    lookup = mocker.patch("main.views.get_link_title", return_value="A" * 2000)
    response = client.post(
        reverse("new_link", args=[private_casebook]),
        {"url": "https://example.com/", "name": name},
        as_user=private_casebook.testing_editor,
    )
    assert response.status_code == 302
    resource = private_casebook.contents.get()
    assert resource.title == (name or "A" * 1024)
    assert resource.resource.name == resource.title
    if name:
        lookup.assert_not_called()
    else:
        lookup.assert_called_once_with("https://example.com/")
