from datetime import date

from typing import Dict
from urllib.parse import urlencode
from django import forms
from django.http import HttpRequest
from django.shortcuts import render
from django.db import connection
from django.contrib.admin.widgets import AdminDateWidget
from dateutil.relativedelta import relativedelta
from django.contrib.admin.views.decorators import staff_member_required

from reporting.create_reporting_views import (
    ALL_STATES,
    OLDEST_YEAR,
    PUBLISHED_CASEBOOKS,
)
from main.models import Casebook
from reporting.matomo import usage


class DateForm(forms.Form):
    start_date = forms.DateField(required=False, widget=AdminDateWidget(attrs={"type": "date"}))
    end_date = forms.DateField(required=False, widget=AdminDateWidget(attrs={"type": "date"}))
    published = forms.BooleanField(
        required=False, initial=True, help_text="Published casebooks only"
    )


@staff_member_required
def view(request: HttpRequest):
    """Render a usage dashboard of useful metrics"""

    stats: Dict[str, int] = {}
    today = date.today()
    oldest = today - relativedelta(years=OLDEST_YEAR)  # A long time ago

    start_date = oldest
    end_date = today
    published_casebooks_only = True

    if "start_date" in request.GET or "end_date" in request.GET:
        form = DateForm(request.GET)

        if form.is_valid():
            start_date = form.cleaned_data["start_date"]
            end_date = form.cleaned_data["end_date"]
            published_casebooks_only = form.cleaned_data["published"]
    else:
        form = DateForm(
            initial={
                "start_date": start_date,
                "end_date": end_date,
                "published": published_casebooks_only,
            }
        )

    state = PUBLISHED_CASEBOOKS if published_casebooks_only else ALL_STATES

    # Get the usage data from Matomo:
    web_usage = usage(start_date, end_date, published_casebooks_only)

    with connection.cursor() as cursor:

        # Run the specific queries needed for the reports
        cursor.execute(
            """--sql
        select count(*) from reporting_users
        where date(last_login_at) >= %s
            and date(last_login_at) <= %s
        """,
            [start_date, end_date],
        )
        stats["registered_users"] = cursor.fetchone()[0]

        cursor.execute(
            """--sql
            select count(*) from reporting_casebooks
            where state in %s
                and date(updated_at) >= %s
                and date(updated_at) <= %s
            """,
            [state, start_date, end_date],
        )
        stats["casebooks"] = cursor.fetchone()[0]

        cursor.execute(
            """--sql
        select count(*) from reporting_professors
        where date(last_login_at) >= %s
            and date(last_login_at) <= %s
        """,
            [start_date, end_date],
        )
        stats["verified_professors"] = cursor.fetchone()[0]

        cursor.execute(
            """--sql
        select count(*) from (
        select user_id from reporting_professors_with_casebooks
        where state in %s
            and date(last_login_at) >= %s
            and date(last_login_at) <= %s
            group by user_id
        ) as r
        """,
            [
                (Casebook.LifeCycle.PUBLISHED.value,) if published_casebooks_only else ALL_STATES,
                start_date,
                end_date,
            ],
        )
        stats["profs_with_books"] = cursor.fetchone()[0]

        # Casebooks from verified professors with attribution
        cursor.execute(
            """--sql
            select count(*) from reporting_casebooks_from_professors
            where state in %s
                and date(updated_at) >= %s
                and date(updated_at) <= %s
        """,
            [
                state,
                start_date,
                end_date,
            ],
        )
        stats["casebooks_prof"] = cursor.fetchone()[0]

        # Casebooks including content from Capstone
        cursor.execute(
            """--sql
            select count(*) from reporting_casebooks_including_source_cap
                where state in %s
                and date(updated_at) >= %s
                and date(updated_at) <= %s
            """,
            [
                state,
                start_date,
                end_date,
            ],
        )
        stats["casebooks_cap"] = cursor.fetchone()[0]

        # Casebooks including content from Cap created by verified professors
        cursor.execute(
            """--sql
            select count(*) from reporting_casebooks_including_source_cap rc
                inner join reporting_casebooks_from_professors rp on rp.casebook_id = rc.casebook_id
                where rc.state in %s
                and date(rc.updated_at) >= %s
                and date(rc.updated_at) <= %s
            """,
            [
                state,
                start_date,
                end_date,
            ],
        )
        stats["casebooks_cap_prof"] = cursor.fetchone()[0]

        # Casebooks including content from GPO
        cursor.execute(
            """--sql
            select count(*) from reporting_casebooks_including_source_gpo
                where state in %s
                and date(updated_at) >= %s
                and date(updated_at) <= %s
            """,
            [
                state,
                start_date,
                end_date,
            ],
        )

        stats["casebooks_gpo"] = cursor.fetchone()[0]

        # Casebooks including content from GPO created by verified professors
        cursor.execute(
            """--sql
            select count(*) from reporting_casebooks_including_source_gpo rc
                inner join reporting_casebooks_from_professors rp on rp.casebook_id = rc.casebook_id
                where rc.state in %s
                and date(rc.updated_at) >= %s
                and date(rc.updated_at) <= %s
            """,
            [
                state,
                start_date,
                end_date,
            ],
        )

        stats["casebooks_gpo_prof"] = cursor.fetchone()[0]

        # Casebooks with multiple collaborators
        cursor.execute(
            """--sql
        select count(*) from reporting_casebooks_with_multiple_collaborators
        where state in %s
            and date(updated_at) >= %s
            and date(updated_at) <= %s
        """,
            [
                state,
                start_date,
                end_date,
            ],
        )
        stats["casebooks_with_collaborators"] = cursor.fetchone()[0]

        # Casebooks with multiple collaborators including professors
        cursor.execute(
            """--sql
        select count(*) from reporting_casebooks_with_multiple_collaborators rc
                inner join reporting_casebooks_from_professors rp on rc.casebook_id = rp.casebook_id
                where rc.state in %s
                and date(rc.updated_at) >= %s
                and date(rc.updated_at) <= %s
        """,
            [
                state,
                start_date,
                end_date,
            ],
        )
        stats["casebooks_with_collaborators_prof"] = cursor.fetchone()[0]

        # Series
        cursor.execute(
            """--sql
        select count(*) from reporting_casebooks_series as c
        where c.state in %s
              and date(c.updated_at) >= %s
              and date(c.updated_at) <= %s
        """,
            [
                state,
                start_date,
                end_date,
            ],
        )
        stats["series"] = cursor.fetchone()[0]

        # Series by professors
        # This only checks the most-current title's authorship, but probably sufficient?
        cursor.execute(
            """--sql
        select count(*) from reporting_casebooks_series_from_professors as c
            where c.state in %s
                and date(c.updated_at) >= %s
                and date(c.updated_at) <= %s
        """,
            [state, start_date, end_date],
        )
        stats["series_by_prof"] = cursor.fetchone()[0]

    return render(
        request,
        "admin/reporting/index.html",
        {
            "stats": stats,
            "web_usage": web_usage,
            "date_form": form,
            "query": urlencode(
                {
                    "start_date": start_date,
                    "end_date": end_date,
                    "published": published_casebooks_only,
                }
            ),
            "date_query": urlencode(
                {
                    "start_date": start_date,
                    "end_date": end_date,
                }
            ),
            "date_presets": {
                "last_month": {
                    "start_date": today + relativedelta(months=-1, day=1),
                    "end_date": today + relativedelta(months=-1, day=31),
                    "label": "Last full month",
                },
                "last_30_days": {
                    "start_date": today + relativedelta(days=-30),
                    "end_date": today,
                    "label": "Last 30 days",
                },
                "year_to_date": {
                    "start_date": today + relativedelta(day=1, month=1),
                    "end_date": today,
                    "label": "Year-to-date",
                },
                "all_dates": {
                    "start_date": oldest,
                    "end_date": today,
                    "label": "All time",
                },
            },
        },
    )
