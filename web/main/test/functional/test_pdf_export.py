from urllib.request import urlopen

import pytest
from django.urls import reverse
from playwright.sync_api import Page, expect

from main.celery_tasks import generate_pdf
from main.models import Casebook


@pytest.mark.skip("PDF functionality needs more work to be performant")
@pytest.mark.xdist_group("functional")
def test_pdf_export_file(static_live_server, page: Page):
    """The PDF helper function should generate a PDF for a public casebook"""
    # Needs to be in the published state for the external process to work
    full_casebook = Casebook.objects.filter(state=Casebook.LifeCycle.PUBLISHED.value).first()
    url = static_live_server.url + reverse("printable_pdf", args=[full_casebook])
    output_filename = "example.pdf"
    pdf_url = generate_pdf(url, output_filename, page)
    with urlopen(pdf_url) as result:
        pdf = result.read()
        assert pdf[:4] == b"%PDF"


@pytest.mark.skip("PDF functionality needs more work to be performant")
@pytest.mark.xdist_group("functional")
def test_pdf_view_elisions(static_live_server, page: Page, login_as_default):
    """PDF view mode should render the correct text for elisions"""
    page.goto(static_live_server.url + reverse("printable_pdf", args=[3]))
    expect(page.get_by_text("This paragraph is also elided")).to_be_hidden()
    expect(page.get_by_text("This is the third paragraph")).to_be_hidden()
    expect(page.get_by_text("This is the last paragraph")).to_be_visible()
