# These tests are run through LiveServerTestCase and playwright
from urllib.request import urlopen

import pytest
from django.urls import reverse
from playwright.sync_api import Page, expect

from main.models import Casebook
from main.tasks import generate_pdf


def login(static_live_server, page: Page, user="functional-test@example.edu", password="changeme"):
    """Do the login step for the default user"""
    page.goto(static_live_server.url)
    page.get_by_role("link", name="Sign In").click()
    page.get_by_label("Email address*").fill(user)
    page.get_by_label("Password*").fill(password)
    page.get_by_role("button", name="Sign in").click()


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

    page.get_by_role("link", name="Sign In").click()
    page.get_by_label("Email address*").fill("functional-test@example.edu")
    page.get_by_label("Password*").fill("changeme")
    page.get_by_role("button", name="Sign in").click()
    assert page.locator("text=Please enter a correct email address and password*").count() == 0
    expect(page).to_have_url(f"{static_live_server.url}/")


@pytest.mark.xdist_group("functional")
def test_view_casebook(static_live_server, page: Page, login_as_default):
    """An authenticated user should be able to view their casebooks in edit mode"""
    page.goto(static_live_server.url)
    expect(page.locator(".casebook-info .title")).to_have_text("Simple casebook")
    page.locator(".casebook-info .title").click()
    page.get_by_role("link", name="First content").click()

    expect(page).to_have_url(
        f"{static_live_server.url}/casebooks/1-simple-casebook/resources/1-first-content/annotate/"
    )


@pytest.mark.xdist_group("functional")
def test_pdf_export(static_live_server, page: Page):
    """The PDF helper function should generate a PDF for a public casebook"""
    # Needs to be in the published state for the external process to work
    full_casebook = Casebook.objects.filter(state=Casebook.LifeCycle.PUBLISHED.value).first()
    url = static_live_server.url + reverse("printable_all", args=[full_casebook])
    output_filename = "example.pdf"
    pdf_url = generate_pdf(url + "?print-preview=true", output_filename, page)
    with urlopen(pdf_url) as result:
        pdf = result.read()
        assert pdf[:4] == b"%PDF"


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
