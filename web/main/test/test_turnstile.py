from unittest.mock import Mock, patch

import pytest
import requests
from django.test import Client


@pytest.fixture
def enabled(settings):
    settings.TURNSTILE_SECRET_KEY = "test-secret"


@pytest.mark.parametrize(
    "result,status",
    [
        ({"success": True, "hostname": "testserver", "action": "api_preclearance"}, 204),
        ({"success": False}, 403),
        ({"success": True, "hostname": "other.example", "action": "api_preclearance"}, 403),
        ({"success": True, "hostname": "testserver", "action": "other"}, 403),
        ([], 403),
    ],
)
def test_verify_browser(enabled, client, result, status):
    with patch("main.turnstile.requests.post", return_value=Mock(json=lambda: result)) as post:
        assert client.post("/browser-verification/", {"token": "test-token"}).status_code == status
        assert post.call_args.kwargs["timeout"] == 10
        assert post.call_args.kwargs["data"] == {"secret": "test-secret", "response": "test-token"}


def test_disabled(client):
    assert client.post("/browser-verification/", {"token": "test-token"}).status_code == 503


@pytest.mark.parametrize("token", ["", "x" * 2049])
def test_invalid_token(enabled, client, token):
    with patch("main.turnstile.requests.post") as post:
        assert client.post("/browser-verification/", {"token": token}).status_code == 400
        post.assert_not_called()


def test_validation_unavailable(enabled, client):
    with patch("main.turnstile.requests.post", side_effect=requests.Timeout):
        assert client.post("/browser-verification/", {"token": "test-token"}).status_code == 503


def test_post_and_csrf_required(enabled, client):
    assert client.get("/browser-verification/").status_code == 405
    assert (
        Client(enforce_csrf_checks=True)
        .post("/browser-verification/", {"token": "test-token"})
        .status_code
        == 403
    )
