import pytest
from django.urls import reverse
from playwright.sync_api import Page, expect

from main.models import User


@pytest.mark.xdist_group("functional")
def test_reorder_resources(
    static_live_server, page: Page, login_as_default, private_casebook_factory, resource_factory
):
    """Dragging a resource updates both the visible order and the saved outline."""
    user = User.objects.get(email_address="functional-test@example.edu")
    casebook = private_casebook_factory(contentcollaborator_set__user=user)
    resources = [
        resource_factory(
            casebook=casebook, ordinals=[i], resource_type="TextBlock", title=f"Reading {i}"
        )
        for i in range(1, 4)
    ]
    page.goto(static_live_server.url + reverse("edit_casebook", args=[casebook]))
    first = page.locator(f".nestable-item-{resources[0].id}")
    second = page.locator(f".nestable-item-{resources[1].id}")
    expect(first).to_be_visible()
    second.scroll_into_view_if_needed()
    handle = first.locator(".nestable-handle").bounding_box()
    target = second.locator(".nestable-item-content").first.bounding_box()
    assert handle is not None and target is not None
    x = handle["x"] + handle["width"] / 2
    y = handle["y"] + handle["height"] / 2
    page.mouse.move(x, y)
    page.mouse.down()
    page.mouse.move(x, y + 8, steps=3)
    expect(page.locator(".nestable-drag-layer .nestable-item-copy")).to_be_visible()
    with page.expect_response(
        lambda response: response.request.headers.get("x-http-method-override") == "PATCH"
    ) as saved:
        page.mouse.move(x, target["y"] + target["height"] - 3, steps=20)
        page.mouse.up()
    assert saved.value.ok
    expect(page.locator(".nestable-item-content a.section-title")).to_have_text(
        ["Reading 2", "Reading 1", "Reading 3"]
    )
    page.reload()
    resources[0].refresh_from_db()
    resources[1].refresh_from_db()
    assert resources[0].ordinals == [2]
    assert resources[1].ordinals == [1]
