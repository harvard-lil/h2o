# These tests are run through LiveServerTestCase and playwright
from pathlib import Path
import re
from django.urls import reverse
from django.core.management import call_command

import pytest
from playwright.sync_api import Page, expect
from pytest_django.live_server_helper import LiveServer

from main.tasks import generate_pdf
from main.models import Casebook


@pytest.fixture(autouse=True, scope="function")
def load_fixtures(transactional_db, django_db_serialized_rollback):
    call_command(
        "loaddata",
        [
            "main/test/functional/fixtures/casebooks.json",
            "main/test/functional/fixtures/contentcollaborators.json",
            "main/test/functional/fixtures/contentnodes.json",
            "main/test/functional/fixtures/textblocks.json",
            "main/test/functional/fixtures/users.json",
        ],
    )


# Ensure that staticfiles has been dropped from the app list before the live_server constructor runs.
# Implementation of this fix: https://github.com/pytest-dev/pytest-django/issues/294#issuecomment-1269236192
# This fixture be deleted when there's a better mechanism upstream to handle.
@pytest.fixture
def static_live_server(request, settings):
    if "django.contrib.staticfiles" in settings.INSTALLED_APPS:
        settings.INSTALLED_APPS.remove("django.contrib.staticfiles")
    server = LiveServer("localhost")
    request.addfinalizer(server.stop)
    return server


@pytest.fixture
def login_as_default(static_live_server, page):
    login(static_live_server, page)


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
def test_pdf_export(static_live_server, page: Page, tmp_path: Path):
    """The PDF helper function should generate a PDF for a public casebook"""
    # Needs to be in the published state for the external process to work
    full_casebook = Casebook.objects.filter(state=Casebook.LifeCycle.PUBLISHED.value).first()
    url = static_live_server.url + reverse("printable_all", args=[full_casebook])
    output_file = tmp_path / "example.pdf"
    generate_pdf(url + "?print-preview=true", output_file, page)
    assert output_file.read_bytes()[:4] == b"%PDF"


@pytest.mark.xdist_group("functional")
def test_print_preview_page(static_live_server, page: Page, full_casebook):
    """The print preview page should be renderable and closeable"""
    login(static_live_server, page, user="functional-staff@example.edu")
    url = (
        static_live_server.url
        + reverse("printable_all", args=[full_casebook])
        + "?print-preview=true"
    )
    page.goto(url)
    expect(page.locator("main.preview-ready")).not_to_be_empty()
    page.get_by_role("button", name="Exit preview").click()
    expect(page).to_have_url(re.compile(f"^{static_live_server.url}/casebooks/3-some-title"))


@pytest.mark.xdist_group("functional")
def test_reading_mode_nav(static_live_server, page: Page, full_casebook):
    """Reading mode should allow users to visit the content and navigate between chapters"""
    login(static_live_server, page, user="functional-staff@example.edu")

    page.goto(static_live_server.url + reverse("as_printable_html", args=[full_casebook]))
    expect(page.locator("main.preview-ready")).not_to_be_empty()
    page.get_by_role("option", name="1 of 2 sections")
    page.locator("#page-selector").select_option(label="2 of 2 sections")
    page.get_by_role("option", name="2 of 2 sections")
    expect(page).to_have_url(re.compile("/as-printable-html/2/$"))


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
