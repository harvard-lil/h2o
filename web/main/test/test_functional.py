# These tests are run through LiveServerTestCase and playwright
from playwright.sync_api import expect


def test_home(live_server, page):
    page.goto(live_server.url)
    expect(page).to_have_title("Open Casebooks | H2O")
