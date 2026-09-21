import socket
import pytest
from main.public_http import (
    PublicHTTPAdapter,
    PublicHTTPConnection,
    PublicHTTPSConnection,
    UnsafeDestination,
    get_public_html,
    public_addresses,
)
from main.utils import get_link_title


def dns_answer(address):
    return (
        socket.AF_INET6 if ":" in address else socket.AF_INET,
        socket.SOCK_STREAM,
        6,
        "",
        (address, 443),
    )


@pytest.mark.parametrize(
    "address",
    [
        "127.0.0.1",
        "10.0.0.1",
        "172.16.0.1",
        "192.168.1.1",
        "169.254.169.254",
        "0.0.0.0",
        "100.64.0.1",
        "224.0.0.1",
        "::1",
        "fc00::1",
        "fe80::1",
        "::ffff:127.0.0.1",
        "2002:7f00:1::",
        "ff02::1",
    ],
)
def test_private_and_special_destinations_never_connect(mocker, address):
    mocker.patch("main.public_http.socket.getaddrinfo", return_value=[dns_answer(address)])
    connect = mocker.patch("main.public_http.create_connection")
    with pytest.raises(UnsafeDestination):
        PublicHTTPSConnection("example.com")._new_conn()
    connect.assert_not_called()


def test_mixed_dns_answers_rejected(mocker):
    mocker.patch(
        "main.public_http.socket.getaddrinfo",
        return_value=[dns_answer("93.184.216.34"), dns_answer("10.0.0.1")],
    )
    with pytest.raises(UnsafeDestination):
        public_addresses("example.com", 443)


@pytest.mark.parametrize("connection_class", [PublicHTTPConnection, PublicHTTPSConnection])
def test_connection_pins_validated_address_but_keeps_hostname(mocker, connection_class):
    dns = mocker.patch(
        "main.public_http.socket.getaddrinfo", return_value=[dns_answer("93.184.216.34")]
    )
    connect = mocker.patch("main.public_http.create_connection")
    connection = connection_class("example.com", port=443, timeout=3)
    assert connection._new_conn() is connect.return_value
    assert connect.call_args.args[0] == ("93.184.216.34", 443)
    assert connection.host == "example.com"
    assert connection._dns_host == "example.com"
    dns.assert_called_once()
    # A later connection revalidates DNS instead of trusting an earlier lookup.
    dns.return_value = [dns_answer("127.0.0.1")]
    with pytest.raises(UnsafeDestination):
        connection._new_conn()
    assert connect.call_count == 1


@pytest.mark.parametrize(
    "url",
    [
        "ftp://example.com/",
        "http://user:pass@example.com/",
        "http://example.com:8000/",
        "http://[bad/",
    ],
)
def test_invalid_url_never_reaches_transport(mocker, url):
    get = mocker.patch("main.public_http.requests.Session.get")
    with pytest.raises(UnsafeDestination):
        get_public_html(url)
    get.assert_not_called()


def test_redirect_destination_is_validated(requests_mock, mocker):
    requests_mock.get(
        "https://example.com/", status_code=302, headers={"Location": "http://127.0.0.1/"}
    )
    # Inspect the real transport used for the redirected request while allowing
    # the public response above to be mocked.
    requests_mock.get("http://127.0.0.1/", real_http=True)
    mocker.patch("main.public_http.socket.getaddrinfo", return_value=[dns_answer("127.0.0.1")])
    connect = mocker.patch("main.public_http.create_connection")
    assert get_link_title("https://example.com/") == "https://example.com/"
    connect.assert_not_called()


def test_public_redirect_and_no_ambient_auth(requests_mock, mocker):
    netrc = mocker.patch("requests.sessions.get_netrc_auth", return_value=("synthetic", "unused"))
    requests_mock.get("https://example.com/", status_code=302, headers={"Location": "/page"})
    requests_mock.get(
        "https://example.com/page",
        text="<html><head><title>Redirected</title></head></html>",
        headers={"Content-Type": "text/html"},
    )
    assert get_link_title("https://example.com/") == "Redirected"
    assert all("Authorization" not in request.headers for request in requests_mock.request_history)
    netrc.assert_not_called()


def test_proxy_fails_closed():
    with pytest.raises(UnsafeDestination):
        PublicHTTPAdapter().proxy_manager_for("http://configured-proxy:8080")


def test_redirect_loop_is_bounded(requests_mock):
    requests_mock.get("https://example.com/", status_code=302, headers={"Location": "/"})
    assert get_public_html("https://example.com/") == b""
    assert requests_mock.call_count == 6


def test_redirect_body_is_not_consumed(requests_mock, mocker):
    requests_mock.get("https://example.com/", status_code=302, headers={"Location": "/page"})
    requests_mock.get("https://example.com/page", status_code=204)
    consume = mocker.patch(
        "requests.Response.iter_content", side_effect=AssertionError("Unexpected body read")
    )
    assert get_public_html("https://example.com/") == b""
    consume.assert_not_called()
