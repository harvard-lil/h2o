import logging
from pathlib import Path
import tempfile
from time import sleep

from celery import shared_task
from playwright.sync_api import sync_playwright, expect, Page

logger = logging.getLogger("celery.django")


@shared_task
def pdf_from_user(url: str, slug: str):
    output_file = tempfile.mkdtemp() / Path(f"{slug}.pdf")
    with sync_playwright() as p:
        logger.info("Launching browser")
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        return generate_pdf(url, output_file, page)


def generate_pdf(
    url: str,
    output_file: Path,
    page: Page,
    selector: str = "main.preview-ready",
    timeout=120_000,
):
    """Generate a PDF from a given URL, return a Path object to the pdf on the filesystem"""
    logger.info(f"Requesting {url}...")

    resp = page.goto(url)

    assert resp
    assert resp.ok
    assert "/accounts/login" not in resp.url

    logger.info(
        f"Got status code {resp.status}, waiting for printable page and selector {selector}"
    )
    page.on("console", lambda msg: logger.warning(f"From browser console: {msg}"))
    expect(page.locator(selector)).to_be_visible(timeout=timeout)
    pdf = page.pdf()
    output_file.write_bytes(pdf)

    logger.info(f"Wrote output to {output_file}")
    return output_file


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


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "url", help="The URL to the pdf endpoint. Must be a publicly-accessible URL"
    )
    parser.add_argument("pdf", help="Fully-qualified path including filename for the PDF output")
    parser.add_argument("--headed", action="store_true", help="Run in headed mode")
    args = parser.parse_args()
    output_file = Path(args.pdf)

    with sync_playwright() as p:
        logger.info("Launching browser")
        browser = p.chromium.launch(headless=not args.headed)
        page = browser.new_page()
        generate_pdf(args.url, output_file, page)
