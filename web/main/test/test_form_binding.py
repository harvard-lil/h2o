import pytest
from django.urls import reverse


@pytest.mark.parametrize(
    "endpoint", ["sign_up", "edit_user", "edit_casebook", "edit_section", "link", "text"]
)
def test_get_is_unbound_and_empty_post_is_validated(client, full_private_casebook, endpoint):
    casebook = full_private_casebook
    user = casebook.testing_editor
    if endpoint in ("sign_up", "edit_user"):
        url = reverse(endpoint)
    elif endpoint == "edit_casebook":
        url = casebook.get_edit_url()
    elif endpoint == "edit_section":
        url = casebook.sections.first().get_edit_url()
    else:
        resource_type = "Link" if endpoint == "link" else "TextBlock"
        url = casebook.contents.filter(resource_type=resource_type).first().get_edit_url()

    response = client.get(url, as_user=user)
    assert response.status_code == 200
    assert not response.context["form"].is_bound
    assert not response.context["form"].errors
    if endpoint in ("link", "text"):
        assert not response.context["embedded_resource_form"].is_bound

    response = client.post(url, {}, as_user=user)
    assert response.status_code == 200
    assert response.context["form"].is_bound
    assert response.context["form"].errors
    if endpoint in ("link", "text"):
        assert response.context["embedded_resource_form"].is_bound
