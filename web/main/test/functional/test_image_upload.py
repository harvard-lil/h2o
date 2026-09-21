from pathlib import Path

import pytest
from playwright.sync_api import expect

from main.models import Resource, SavedImage, User


@pytest.mark.xdist_group("functional")
@pytest.mark.parametrize("editor_id", ["id_headnote", "id_content"])
def test_uploaded_image_survives_save(static_live_server, page, login_as_default, editor_id):
    """Uploaded images must retain their URL through TinyMCE and Django serialization."""
    User.objects.filter(email_address="functional-test@example.edu").update(verified_professor=True)
    page.goto(
        static_live_server.url + "/casebooks/1-simple-casebook/resources/1-first-content/edit/"
    )
    editor = page.frame_locator(f"#{editor_id}_ifr").locator("body")
    expect(editor).to_be_editable()
    editor.fill("")
    toolbar = page.locator(".tox-tinymce").filter(has=page.locator(f"#{editor_id}_ifr"))
    toolbar.get_by_role("button", name="Reveal or hide additional toolbar items").click()
    page.get_by_role("button", name="Insert/edit image", exact=True).click()
    dialog = page.get_by_role("dialog", name="Insert/Edit Image")
    dialog.get_by_role("tab", name="Upload", exact=True).click()
    with page.expect_file_chooser() as chooser:
        dialog.get_by_role("button", name="Browse for an image").click()
    with page.expect_response(
        lambda response: response.request.method == "POST" and response.url.endswith("/image/")
    ) as uploaded:
        chooser.value.set_files(Path(__file__).parents[3] / "static/images/add-icon.png")
    assert uploaded.value.status == 200
    assert uploaded.value.request.headers["content-type"].startswith("multipart/form-data;")
    image_url = uploaded.value.json()["location"]
    saved_image = SavedImage.objects.get()
    assert image_url == static_live_server.url + saved_image.url
    expect(dialog.get_by_role("combobox", name="Source", exact=True)).to_have_value(image_url)
    dialog.get_by_role("textbox", name="Alternative description").fill("Uploaded test image")
    dialog.get_by_role("button", name="Save", exact=True).click()
    expect(editor.get_by_role("img", name="Uploaded test image")).to_have_attribute(
        "src", image_url
    )
    with page.expect_navigation(wait_until="load"):
        page.get_by_role("complementary").get_by_role("button", name="Save", exact=True).click()
    resource = Resource.objects.get(pk=1)
    markup = resource.headnote if editor_id == "id_headnote" else resource.resource.content
    assert f'src="{image_url}"' in markup
    page.reload()
    expect(editor.get_by_role("img", name="Uploaded test image")).to_have_attribute(
        "src", image_url
    )
