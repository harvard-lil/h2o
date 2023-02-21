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
    expect(page).to_have_url(re.compile("/as-printable-html/2/$"))
