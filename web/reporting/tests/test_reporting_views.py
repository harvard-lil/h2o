import dateutil.rrule as rrule
import csv
import datetime
from io import StringIO

import pytest
from django.apps import apps
from django.db import connection
from django.http import HttpResponse
from django.test import override_settings
from django.urls import reverse
from freezegun import freeze_time
from main.models import CasebookEditLog
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


@override_settings(
    MATOMO_SITE_URL="http://example.com", MATOMO_API_KEY="fake", MATOMO_SITE_ID="fake"
)
def test_usage_dashboard(
    client, casebook_factory, mock_successful_matomo_response, admin_user_factory
):
    """The reporting dashboard should return a datastructure with result counts"""
    casebook_factory()
    refresh()
    resp = client.get(reverse("admin:usage"), as_user=admin_user_factory())
    assert 1 == resp.context["stats"]["casebooks"]


@override_settings(
    MATOMO_SITE_URL="http://example.com", MATOMO_API_KEY="fake", MATOMO_SITE_ID="fake"
)
def test_dashboard_casebook_date_fields(
    client,
    casebook_factory,
    casebook_edit_log_factory,
    mock_successful_matomo_response,
    admin_user_factory,
):
    """The reporting dashboard should report dates based on casebook usage including the edit log"""

    early_date = "2000-01-01"
    later_date = "2050-01-01"

    admin = admin_user_factory()

    # Pick a time to create a casebook and then check whether any exist "now"
    with freeze_time(early_date):
        casebook = casebook_factory()
        refresh()
        resp = client.get(
            reverse("admin:usage"),
            {"start_date": early_date, "end_date": early_date},
            as_user=admin,
        )
        assert 1 == resp.context["stats"]["casebooks"]

    with freeze_time(later_date):
        # At a later time, casebook will no longer fall in the filter range
        resp = client.get(
            reverse("admin:usage"),
            {"start_date": later_date, "end_date": later_date},
            as_user=admin,
        )
        assert 0 == resp.context["stats"]["casebooks"]

        # However, if we generate new edit log values...
        casebook_edit_log_factory(casebook=casebook)
        refresh()

        # The casebook is now considered to be modified recently
        resp = client.get(
            reverse("admin:usage"),
            {"start_date": later_date, "end_date": later_date},
            as_user=admin,
        )
        assert 1 == resp.context["stats"]["casebooks"]


def test_greatest_mod_date(casebook_edit_log_factory, casebook_factory, cursor):
    """The `updated_at` date in the reporting table for a casebook should be the most recent
    date of any edit log value, or the casebook itself"""
    with freeze_time("1970-01-01"):
        casebook = casebook_factory()

        for recurring_date in rrule.rrule(rrule.YEARLY, count=10):
            # Generate 10 edit log entries
            with freeze_time(recurring_date):
                casebook_edit_log_factory(casebook=casebook)

    assert 10 == CasebookEditLog.objects.count()
    max_date = CasebookEditLog.objects.all().order_by("-entry_date").first().entry_date
    refresh()

    cursor.execute(
        "select updated_at from reporting_casebooks where casebook_id = %s",
        [casebook.id],
    )
    rows = cursor.fetchall()

    # There should only be 1 entry...
    assert 1 == len(rows)

    # ...and its date should be the max date of the edit log values, which are more recent than
    # the casebook
    assert max_date == rows[0][0]

    # Jump ahead into the future and update the casebook's timestamp
    with freeze_time("2099-01-01"):
        casebook.save()
        refresh()
        cursor.execute(
            "select updated_at from reporting_casebooks where casebook_id = %s",
            [casebook.id],
        )
        rows = cursor.fetchall()

        # Now the reporting table greatest date should apply to the casebook, not the edit log
        assert max_date < rows[0][0]


@pytest.mark.parametrize("model", apps.all_models["reporting"])
def test_reporting_view_pages(client, model, admin_user_factory):
    """All reporting views should return successful default responses"""
    admin = admin_user_factory()
    resp = client.get(reverse(f"admin:reporting_{model}_changelist"), as_user=admin)
    assert 200 == resp.status_code


@pytest.mark.parametrize("model", apps.all_models["reporting"])
def test_reporting_csv_export(client, admin_user_factory, model):
    """All reporting views should allow exporting via CSV"""
    admin = admin_user_factory()

    resp: HttpResponse = client.get(
        reverse(
            f"admin:reporting_{model}_changelist",
        ),
        {"_csv": True},
        as_user=admin,
    )
    assert resp.headers.get("Content-Type") == "text/csv"
    # Content should be a one-line CSV, just the header fields
    rows = list(csv.reader(StringIO(resp.content.decode())))
    assert "id" in rows[0][0]


def test_reporting_csv_export_casebook(client, admin_user_factory, casebook_factory):
    """The casebook export view should export some expected fields"""
    admin = admin_user_factory()

    with freeze_time("2020-01-02"):
        c = casebook_factory()
        refresh()
        resp: HttpResponse = client.get(
            reverse(
                "admin:reporting_reportingcasebook_changelist",
            ),
            {"_csv": True, "start_date": "2020-01-01", "end_date": "2020-01-03"},
            as_user=admin,
        )
        rows = list(csv.reader(StringIO(resp.content.decode())))
        assert 2 == len(rows)
        assert "title" in rows[0]
        assert c.title in rows[1]


def test_reporting_csv_export_professor(client, admin_user_factory, verified_professor_factory):
    """The professor export view should export some expected fields"""

    with freeze_time("2020-01-02"):
        p = verified_professor_factory()
        # Manually set the logged-in date, because the test client does not call this pathway
        p.last_login_at = datetime.datetime.now()
        p.save()

        refresh()
        resp: HttpResponse = client.get(
            reverse(
                "admin:reporting_professor_changelist",
            ),
            {"_csv": True, "start_date": "2020-01-01", "end_date": "2020-01-03"},
            as_user=admin_user_factory(),
        )
        rows = list(csv.reader(StringIO(resp.content.decode())))
        assert 2 == len(rows)
        assert "affiliation" in rows[0]
        assert p.affiliation in rows[1]
