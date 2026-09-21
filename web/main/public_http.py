"""HTTP transport for optional metadata fetched from user-supplied public URLs.

Resolve and validate at connection time, then connect to that numeric address.
TLS and Host continue to use the original hostname. Never resolve through a proxy
or reuse the application's ambient HTTP credentials.
"""

import ipaddress
import socket
from urllib.parse import urljoin, urlsplit

import requests
from requests.adapters import HTTPAdapter
from requests.auth import AuthBase
from urllib3.connection import HTTPConnection, HTTPSConnection
from urllib3.connectionpool import HTTPConnectionPool, HTTPSConnectionPool
from urllib3.exceptions import NewConnectionError
from urllib3.util.connection import create_connection


class UnsafeDestination(requests.RequestException):
    pass


def validate_url(url):
    try:
        parsed = urlsplit(url)
        port = parsed.port
    except ValueError as error:
        raise UnsafeDestination("Invalid metadata URL") from error
    if (
        parsed.scheme not in {"http", "https"}
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or port not in {None, 80, 443}
    ):
        raise UnsafeDestination("Metadata lookup requires a public HTTP(S) URL")


def public_addresses(host, port):
    answers = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    addresses = list(dict.fromkeys(answer[4][0] for answer in answers))
    if not addresses:
        raise UnsafeDestination("No metadata destination")
    for address in addresses:
        ip = ipaddress.ip_address(address)
        # Reject scoped addresses and transition mechanisms with embedded IPv4 destinations.
        if (
            not ip.is_global
            or ip.is_multicast
            or ip.is_reserved
            or "%" in address
            or (
                isinstance(ip, ipaddress.IPv6Address)
                and (ip.ipv4_mapped or ip.sixtofour or ip.teredo)
            )
        ):
            raise UnsafeDestination("Metadata destination is not public")
    return addresses


class PublicConnection:
    def _new_conn(self):
        try:
            addresses = public_addresses(self._dns_host, self.port)
            last_error = None
            for address in addresses:
                try:
                    # The numeric literal cannot be rebound to a different address by DNS.
                    return create_connection(
                        (address, self.port),
                        self.timeout,
                        source_address=self.source_address,
                        socket_options=self.socket_options,
                    )
                except OSError as error:
                    last_error = error
            raise NewConnectionError(self, "Public metadata connection failed") from last_error
        except UnsafeDestination:
            raise
        except OSError as error:
            raise NewConnectionError(self, "Public metadata resolution failed") from error


class PublicHTTPConnection(PublicConnection, HTTPConnection):
    pass


class PublicHTTPSConnection(PublicConnection, HTTPSConnection):
    pass


class PublicHTTPPool(HTTPConnectionPool):
    ConnectionCls = PublicHTTPConnection


class PublicHTTPSPool(HTTPSConnectionPool):
    ConnectionCls = PublicHTTPSConnection


class PublicHTTPAdapter(HTTPAdapter):
    def init_poolmanager(self, *args, **kwargs):
        super().init_poolmanager(*args, **kwargs)
        self.poolmanager.pool_classes_by_scheme = {"http": PublicHTTPPool, "https": PublicHTTPSPool}

    def proxy_manager_for(self, proxy, **kwargs):
        # A proxy can resolve to private destinations outside this validation boundary.
        # Fail optional lookup instead of bypassing an explicitly configured route.
        raise UnsafeDestination("Metadata lookup is unavailable through a proxy")


class PublicSession(requests.Session):
    def resolve_redirects(self, response, request, **kwargs):
        # Redirects are followed explicitly below. Even with allow_redirects=False,
        # requests normally prepares response.next, consuming the redirect body
        # without our size limit and consulting netrc for the next destination.
        return iter(())


class NoAmbientAuth(AuthBase):
    def __call__(self, request):
        return request


def get_public_html(url):
    """Return at most 1 MiB of HTML, following at most five validated redirects."""
    with PublicSession() as session:
        adapter = PublicHTTPAdapter(max_retries=0)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        for _ in range(6):
            validate_url(url)
            with session.get(
                url, timeout=(3.05, 10), stream=True, allow_redirects=False, auth=NoAmbientAuth()
            ) as response:
                if response.is_redirect:
                    url = urljoin(url, response.headers["Location"])
                    continue
                content_type = response.headers.get("Content-Type", "").split(";", 1)[0].lower()
                if not response.ok or content_type not in {"text/html", "application/xhtml+xml"}:
                    return b""
                body = bytearray()
                for chunk in response.iter_content(chunk_size=16384):
                    body.extend(chunk)
                    if len(body) > 1024 * 1024:
                        return b""
                return bytes(body)
        return b""
