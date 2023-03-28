import re

import pytest
from django.urls import reverse
from playwright.sync_api import Page, expect

from .test_platform import login


@pytest.mark.xdist_group("functional")
def test_reading_mode_nav(static_live_server, page: Page, full_casebook):
    """Reading mode should allow users to visit the content and navigate between chapters"""
    login(static_live_server, page, user="functional-staff@example.edu")

    page.goto(static_live_server.url + reverse("as_printable_html", args=[full_casebook]))
    expect(page.locator("main")).not_to_be_empty()
    page.get_by_role("option", name="1 of 2 sections")
    page.locator("#page-selector").select_option(label="2 of 2 sections")
    page.get_by_role("option", name="2 of 2 sections")
    expect(page).to_have_url(re.compile("/as-printable-html/2/"))


@pytest.mark.xdist_group("functional")
def test_reading_mode_elisions(static_live_server, page: Page, login_as_default):
    """Reading mode should render the correct text for elisions"""
    page.goto(static_live_server.url + reverse("as_printable_html", args=[3]))
    expect(page.get_by_text("[…]")).to_be_visible()
    expect(page.get_by_text("This paragraph is also elided")).to_be_hidden()
    expect(page.get_by_text("This is the third paragraph")).to_be_hidden()
    expect(page.get_by_text("This is the last paragraph")).to_be_visible()


@pytest.mark.xdist_group("functional")
def test_reading_mode_highlights(static_live_server, page: Page, login_as_default):
    """Reading mode should mark up highlights"""
    page.goto(static_live_server.url + reverse("as_printable_html", args=[3]))
    highlight = page.locator("mark.highlighted")
    expect(highlight).to_have_text("This sentence is highlighted.")
    expect(highlight).to_be_visible()


@pytest.mark.xdist_group("functional")
def test_reading_mode_correction(static_live_server, page: Page, login_as_default):
    """Reading mode should render corrected text"""
    page.goto(static_live_server.url + reverse("as_printable_html", args=[3]))
    expect(page.locator("ins").get_by_text("corrected")).to_be_visible()
    assert page.locator("del.correction").count() == 1
    expect(page.get_by_text("corected")).to_be_hidden()


@pytest.mark.xdist_group("functional")
def test_reading_mode_replacement(static_live_server, page: Page, login_as_default):
    """Reading mode should render replaced text"""
    page.goto(static_live_server.url + reverse("as_printable_html", args=[3]))
    expect(page.locator("ins").get_by_text("word replaced")).to_be_visible()
    assert page.locator("del.replace").count() == 1
    expect(page.get_by_text("replacement")).to_be_hidden()


@pytest.mark.xdist_group("functional")
def test_reading_mode_note(static_live_server, page: Page, login_as_default):
    """Reading mode should render notes"""
    page.goto(static_live_server.url + reverse("as_printable_html", args=[3]))
    expect(page.locator("mark.note-mark").get_by_text("here")).to_be_visible()
    expect(page.locator("aside").get_by_text("Here is the note")).to_be_visible()
