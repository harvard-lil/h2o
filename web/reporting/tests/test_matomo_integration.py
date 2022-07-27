from datetime import date
from functools import partial

import pytest
import requests
from main.models import Casebook
from reporting.matomo import api
from requests_mock import ANY


@pytest.mark.django_db(transaction=True, reset_sequences=True)
def test_matomo_api(casebook_factory, mock_successful_matomo_response):
    """The API call should find matching casebooks from the usage data"""

    c1 = casebook_factory()
    c2 = casebook_factory()
    res = api("http://example.com", "", "", date.today(), date.today())
    assert res.items[0].instance.id == c1.id
    assert res.items[1].instance.id == c2.id


@pytest.mark.django_db(transaction=True, reset_sequences=True)
def test_matomo_api_filter(casebook_factory, mock_successful_matomo_response):
    """The API call should respect the publication filter"""

    c1 = casebook_factory(state=Casebook.LifeCycle.PUBLISHED.value)
    casebook_factory(state=Casebook.LifeCycle.ARCHIVED.value)

    res = api(
        "http://example.com", "", "", date.today(), date.today(), published_casebooks_only=True
    )
    assert res.items[0].instance.id == c1.id
    assert res.items[1].instance is None


@pytest.mark.django_db(transaction=True, reset_sequences=True)
def test_matomo_api_no_match(mock_successful_matomo_response):
    """The API call should still return some data even if the casebooks can't be found in the DB"""

    res = api("http://example.com", "", "", date.today(), date.today())
    assert res.items[0].slug == "1-some-title"
    assert res.items[0].instance is None


def test_matomo_api_error(requests_mock):
    """The API call should be resilient to the Matomo API being unavailable"""

    api_call = partial(api, "http://example.com", "", "", date.today(), date.today())
    requests_mock.get(ANY, status_code=500)
    res = api_call()
    assert "error" in res.status

    requests_mock.get(ANY, exc=requests.exceptions.ConnectTimeout)
    res = api_call()
    assert "error" in res.status

    requests_mock.get(ANY, text="I'm not JSON")
    res = api_call()
    assert "did not return JSON" in res.status
