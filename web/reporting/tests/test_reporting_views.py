import pytest
from django.apps import apps
from django.db import connection
from django.urls import reverse
from reporting.create_reporting_views import VIEW_LIST, create, refresh


@pytest.fixture(autouse=True)
def create_reporting_views(db):
    create()


@pytest.fixture()
def cursor(db):
    yield connection.cursor()


@pytest.mark.parametrize("view,count", zip(VIEW_LIST, [0] * len(VIEW_LIST)))
def test_create_empty_reporting_views(db, view, count, cursor):
    """Creating views of reporting tables should succeed even with no data"""
    cursor.execute(f"select count(*) from {view}")
    assert count == cursor.fetchone()[0]


def test_refresh_views(db, casebook_factory, cursor):
    """Refreshing the views should update based on the state of the database"""
    cursor.execute("select count(*) from reporting_casebooks")
    assert 0 == cursor.fetchone()[0]
    casebook_factory()
    refresh()
    cursor.execute("select count(*) from reporting_casebooks")
    assert 1 == cursor.fetchone()[0]


def test_usage_dashboard(client, casebook_factory, mock_successful_matomo_response):
    """The reporting dashboard should return a datastructure with result counts"""
    casebook_factory()
    refresh()
    resp = client.get(reverse("admin:usage"))
    assert 1 == resp.context["stats"]["casebooks"]


@pytest.mark.parametrize("model", apps.all_models["reporting"])
def test_reporting_views(client, model, admin_user_factory):
    """All reporting views should return successful default responses"""
    admin = admin_user_factory()
    client.force_login(admin)
    resp = client.get(reverse(f"admin:reporting_{model}_changelist"))
    assert 200 == resp.status_code
