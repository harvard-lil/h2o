import pytest
import requests
from lxml import etree

from main.utils import get_link_title


@pytest.mark.parametrize("content_type", ["text/html; charset=utf-8", "application/xhtml+xml"])
def test_html_title(requests_mock, content_type):
    requests_mock.get(
        "https://example.com/",
        text="<html><title>Example &amp; title</title></html>",
        headers={"Content-Type": content_type},
    )
    assert get_link_title("https://example.com/") == "Example & title"


@pytest.mark.parametrize(
    "failure", [requests.Timeout, requests.ConnectionError, requests.exceptions.SSLError]
)
def test_network_failure_uses_filename(requests_mock, failure):
    url = "https://example.com/Example%20document.pdf?api=v2#page=1"
    requests_mock.get(url, exc=failure)
    assert get_link_title(url) == "Example document"


def test_non_html_body_is_not_downloaded(mocker):
    response = mocker.MagicMock(ok=True, headers={"Content-Type": "application/pdf"})
    response.__enter__.return_value = response
    get = mocker.patch("main.utils.requests.get", return_value=response)
    assert get_link_title("https://example.com/Example.pdf?api=v2") == "Example"
    get.assert_called_once_with(
        "https://example.com/Example.pdf?api=v2", timeout=(3.05, 10), stream=True
    )
    response.iter_content.assert_not_called()
    response.__exit__.assert_called_once()


@pytest.mark.parametrize(
    "body", ["", "<html></html>", "<html><title></title></html>", "x" * (1024 * 1024 + 1)]
)
def test_missing_title_or_oversized_html_uses_fallback(requests_mock, body):
    requests_mock.get(
        "https://example.com/reading/", text=body, headers={"Content-Type": "text/html"}
    )
    assert get_link_title("https://example.com/reading/") == "reading"


def test_http_error_uses_fallback(requests_mock):
    requests_mock.get("https://example.com/", status_code=403)
    assert get_link_title("https://example.com/") == "https://example.com/"


def test_unparseable_response_uses_fallback(requests_mock, mocker):
    requests_mock.get("https://example.com/", text="broken", headers={"Content-Type": "text/html"})
    mocker.patch("main.utils.PyQuery", side_effect=etree.ParserError("not a document"))
    assert get_link_title("https://example.com/") == "https://example.com/"
