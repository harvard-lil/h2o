# These tests are run through LiveServerTestCase and playwright

import pytest
from django.urls import reverse
from playwright.sync_api import Page, expect

from main.models import Casebook, User


def login(static_live_server, page: Page, user="functional-test@example.edu", password="changeme"):
    """Do the login step for the default user"""
    page.goto(static_live_server.url)
    page.get_by_role("link", name="Sign In").click()
    expect(page).to_have_url(f"{static_live_server.url}/accounts/login/")
    page.wait_for_load_state("load")
    page.get_by_label("Email address*").fill(user)
    page.get_by_label("Password*").fill(password)
    page.get_by_role("button", name="Sign in").click()
    expect(page).to_have_url(f"{static_live_server.url}/")


@pytest.mark.xdist_group("functional")
def test_home(static_live_server, page: Page):
    """The unauthenticated home page should have the expected content"""
    page.goto(static_live_server.url)
    expect(page).to_have_title("Open Casebooks | H2O")


@pytest.mark.xdist_group("functional")
def test_auth(static_live_server, page: Page):
    """A user with an account should be able to log in"""
    page.goto(static_live_server.url)
    page.get_by_role("link", name="Sign In").click()
    expect(page).to_have_url(f"{static_live_server.url}/accounts/login/")
    page.wait_for_load_state("load")
    page.get_by_label("Email address*").fill("functional-test@example.edu")
    page.get_by_label("Password*").fill("changeme")
    page.get_by_role("button", name="Sign in").click()
    assert page.locator("text=Please enter a correct email address and password*").count() == 0
    expect(page).to_have_url(f"{static_live_server.url}/")


@pytest.mark.xdist_group("functional")
def test_view_casebook(static_live_server, page: Page, login_as_default):
    """An authenticated user should be able to view their casebooks in edit mode"""
    page.goto(static_live_server.url)
    page.get_by_text("Simple casebook").click()
    page.get_by_role("link", name="First content").click()

    expect(page).to_have_url(
        f"{static_live_server.url}/casebooks/1-simple-casebook/resources/1-first-content/annotate/"
    )


@pytest.mark.xdist_group("functional")
def test_print_preview_page(static_live_server, page: Page, full_casebook):
    """The print preview page should be renderable"""
    login(static_live_server, page, user="functional-staff@example.edu")
    url = (
        static_live_server.url
        + reverse("printable_all", args=[full_casebook])
        + "?print-preview=true"
    )
    page.goto(url)
    expect(page.locator("main")).not_to_be_empty()


@pytest.mark.xdist_group("functional")
@pytest.mark.parametrize(
    "user,message,post_publish_message",
    [
        ["functional-prof@example.edu", "You're almost ready to publish", True],
        ["functional-test@example.edu", "Are you ready to publish your book?", False],
    ],
)
def test_publish(static_live_server, user, message, page, post_publish_message):
    """A user should be able to take an unpublished book and publish it in the UI"""
    login(static_live_server, page, user=user)

    casebook = Casebook.objects.filter(state=Casebook.LifeCycle.PRIVATELY_EDITING.value).first()
    page.goto(static_live_server.url + reverse("edit_casebook", args=[casebook]))
    page.get_by_role("button", name="Publish").click()
    expect(page.locator(".modal-body")).to_contain_text(message)
    page.locator(".modal-footer").get_by_role("button", name="Publish").click()
    if post_publish_message:
        expect(page.locator(".modal-title")).to_contain_text("Your book is published")
        page.get_by_role("button", name="OK").click()

    expect(page.locator(".modal-body")).not_to_be_visible()

    expect(page.locator("input[value=Revise]")).to_be_visible()
    casebook.refresh_from_db()
    assert casebook.state == Casebook.LifeCycle.PUBLISHED.value


@pytest.mark.xdist_group("functional")
@pytest.mark.parametrize("static_live_server", ["localhost", "opencasebook.test"], indirect=True)
@pytest.mark.parametrize("enhanced", [False, True])
def test_edit_rich_text(static_live_server, page: Page, login_as_default, enhanced):
    """Rich text changes must survive the editor's form submission and reload."""
    User.objects.filter(email_address="functional-test@example.edu").update(
        verified_professor=enhanced
    )
    page.goto(
        static_live_server.url + "/casebooks/1-simple-casebook/resources/1-first-content/edit/"
    )
    if "opencasebook.test" in static_live_server.url:
        assert page.evaluate("window.isSecureContext") is False
        assert page.evaluate("typeof crypto.randomUUID") == "undefined"
    editor = page.frame_locator("#id_content_ifr").locator("body")
    page.wait_for_function("window.tinymce?.get('id_content')?.initialized")
    expect(editor).to_be_editable()
    editor.fill("Updated rich text content.")
    editor.press("ArrowRight")
    if enhanced:
        toolbar = page.locator(".tox-tinymce").filter(has=page.locator("#id_content_ifr"))
        toolbar.get_by_role("button", name="Reveal or hide additional toolbar items").click()
        page.get_by_role("button", name="Footnote", exact=True).click()
        dialog = page.get_by_role("dialog", name="Footnote")
        dialog.get_by_label("Footnote", exact=True).fill("A saved footnote.")
        dialog.get_by_role("button", name="Save", exact=True).click()
        expect(editor).to_contain_text("A saved footnote.")
    with page.expect_navigation(wait_until="load"):
        page.get_by_role("button", name="Save", exact=True).click()
    page.reload()
    expect(editor).to_contain_text("Updated rich text content.")
    if enhanced:
        expect(editor).to_contain_text("A saved footnote.")
