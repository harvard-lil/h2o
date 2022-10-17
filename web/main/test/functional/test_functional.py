# These tests are run through LiveServerTestCase and playwright
from pathlib import Path
import pytest
from django.core.management import call_command
from playwright.sync_api import Page, expect
from pytest_django.live_server_helper import LiveServer
from main.pdf import generate_pdf
from main.models import Casebook
from django.urls import reverse


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
def test_view_casebook(static_live_server, page: Page, login):
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
    casebook = Casebook.objects.get(title="Public casebook")
    assert casebook
    url = static_live_server.url + reverse("printable_all", args=[casebook])
    output_file = tmp_path / "example.pdf"
    generate_pdf(url, output_file, page)
    assert output_file.read_bytes()[:4] == b"%PDF"
