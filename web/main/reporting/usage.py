from datetime import date

from typing import Dict
from django import forms
from django.http import HttpRequest
from django.shortcuts import render
from django.db import connection
from django.contrib.admin.widgets import AdminDateWidget
from dateutil.relativedelta import *

from main.reporting.create_reporting_views import (
    ALL_STATES,
    OLDEST_YEAR,
    PUBLISHED_CASEBOOKS,
)
from ..models import Casebook, User


class DateForm(forms.Form):
    start_date = forms.DateField(required=False, widget=AdminDateWidget(attrs={"type": "date"}))
    end_date = forms.DateField(required=False, widget=AdminDateWidget(attrs={"type": "date"}))
    published = forms.BooleanField(
        required=False, initial=True, help_text="Published casebooks only"
    )


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

    # Users and derived users have the date filter applied
    users = User.objects.filter(
        is_active=True,
        is_superuser=False,
        created_at__gte=start_date,
        created_at__lte=end_date,
    )
    profs = users.filter(verified_professor=True)

    stats["registered_users"] = users.count()
    stats["verified_professors"] = profs.count()

    # Casebooks also have the creation date filter applied
    casebooks = Casebook.objects.filter(created_at__gte=start_date, created_at__lte=end_date)

    state = ALL_STATES

    if published_casebooks_only:

        casebooks = casebooks.filter(state__in=PUBLISHED_CASEBOOKS)
        state = PUBLISHED_CASEBOOKS

    stats["casebooks"] = casebooks.count()

    with connection.cursor() as cursor:

        # Run the specific queries needed for the reports

        cursor.execute(
            """--sql
        select count(*) from reporting_professors_with_casebooks
        where state in %s
            and created_at >= %s
            and created_at <= %s
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
                and created_at >= %s
                and created_at <= %s
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
            select count(*) from main_casebook where main_casebook.id
                in (select casebook_id from reporting_casebooks_including_source_cap)
                and state in %s
                and created_at >= %s
                and created_at <= %s
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
            select count(*) from main_casebook where main_casebook.id
                in (select casebook_id from reporting_casebooks_including_source_cap)
                and main_casebook.id in
                   (select casebook_id from reporting_casebooks_from_professors)
                and state in %s
                and created_at >= %s
                and created_at <= %s
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
            select count(*) from main_casebook where main_casebook.id
                in (select casebook_id from reporting_casebooks_including_source_gpo)
                and state in %s
                and created_at >= %s
                and created_at <= %s
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
            select count(*) from main_casebook where main_casebook.id
                in (select casebook_id from reporting_casebooks_including_source_gpo)
                and main_casebook.id in
                   (select casebook_id from reporting_casebooks_from_professors)
                and state in %s
                and created_at >= %s
                and created_at <= %s
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
            and created_at >= %s
            and created_at <= %s
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
        select count(*) from main_casebook
            where main_casebook.id
                in (select casebook_id from reporting_casebooks_with_multiple_collaborators)
                and main_casebook.id
                in (select casebook_id from reporting_casebooks_from_professors)
                and state in %s
                and created_at >= %s
                and created_at <= %s
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
        select count(*) from main_commontitle ct
        join main_casebook c on c.id = ct.current_id
        where c.state in %s
              and c.created_at >= %s
              and c.created_at <= %s
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
        select count(*) from main_commontitle
            join reporting_casebooks_from_professors c on c.casebook_id = main_commontitle.current_id
            and c.state in %s
                and c.created_at >= %s
                and c.created_at <= %s
        """,
            [state, start_date, end_date],
        )
        stats["series_by_prof"] = cursor.fetchone()[0]

    return render(
        request,
        "admin/usage/index.html",
        {
            "stats": stats,
            "date_form": form,
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
