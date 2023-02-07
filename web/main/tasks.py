import logging
import os
from datetime import datetime
from time import sleep

from celery import shared_task
from django.conf import settings
from main.storages import get_s3_storage
from playwright.sync_api import Page, expect, sync_playwright

logger = logging.getLogger("celery.django")


@shared_task
def pdf_from_user(url: str, slug: str) -> str:
    with sync_playwright() as p:
        logger.info("Launching browser")
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        url = generate_pdf(url, f"{slug}-{datetime.now().strftime('%Y%m%dT%H%M%S')}.pdf", page)
    return url


def generate_pdf(
    url: str,
    output_filename: str,
    page: Page,
    selector: str = "main.preview-ready",
    timeout=120_000,
) -> str:
    """Generate a PDF from a given URL"""
    logger.info(f"Requesting {url}...")

    resp = page.goto(url)

    assert resp
    assert resp.ok
    if "/accounts/login" in resp.url:
        raise PermissionError()

    logger.info(
        f"Got status code {resp.status}, waiting for printable page and selector {selector}"
    )
    page.on("console", lambda msg: logger.warning(f"From browser console: {msg}"))
    expect(page.locator(selector)).to_be_visible(timeout=timeout)
    pdf = page.pdf()
    storage = get_s3_storage(bucket_name=os.environ["PDF_EXPORT_BUCKET"])
    output_file = storage.open(output_filename, "w")
    output_file.write(pdf)
    output_file.close()
    logger.info(f"Wrote output to {output_file}")
    return storage.url(output_file.name, expire=settings.PDF_AWS_QUERYSTRING_EXPIRE)


@shared_task
def demo_scheduled_task(pause_for_seconds=0):
    """
    A demo task, scheduled to run periodically in dev. To see it in action,
    set CELERY_TASK_ALWAYS_EAGER = False in setting.py before running `fab run`.

    >>> caplog = getfixture('caplog')
    >>> settings = getfixture('settings')
    >>> settings.CELERY_TASK_ALWAYS_EAGER = True
    >>> with caplog.at_level(logging.DEBUG):
    ...     _ = demo_scheduled_task.apply_async(kwargs={'pause_for_seconds': 1})
    >>> assert 'Celerybeat is working!' in caplog.text
    """
    if pause_for_seconds:
        sleep(pause_for_seconds)
    return "Celerybeat is working!"
