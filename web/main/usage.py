from datetime import date

from typing import Dict
from django import forms
from django.http import HttpRequest
from django.shortcuts import render
from django.db import connection
from django.db.models import Count
from django.contrib.admin.widgets import AdminDateWidget
from dateutil.relativedelta import *
from .models import Casebook, User


class DateForm(forms.Form):
    start_date = forms.DateField(
        required=False, widget=AdminDateWidget(attrs={"type": "date"})
    )
    end_date = forms.DateField(
        required=False, widget=AdminDateWidget(attrs={"type": "date"})
    )
    published = forms.BooleanField(
        required=False, initial=True, help_text="Published casebooks only"
    )


def view(request: HttpRequest):
    """Render a usage dashboard of useful metrics"""

    stats: Dict[str, int] = {}

    today = date.today()
    oldest = today - relativedelta(years=20)  # A long time ago

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
    profs_with_books = profs.annotate(has_books=Count("casebooks")).filter(
        has_books__gt=0
    )
    stats["registered_users"] = users.count()
    stats["verified_professors"] = profs.count()
    stats["profs_with_books"] = profs_with_books.count()

    # Casebooks also have the creation date filter applied
    casebooks = Casebook.objects.filter(
        created_at__gte=start_date, created_at__lte=end_date
    )

    state = tuple(tag.value for tag in Casebook.LifeCycle)

    if published_casebooks_only:
        casebooks = casebooks.filter(state=Casebook.LifeCycle.PUBLISHED.value)
        state = (Casebook.LifeCycle.PUBLISHED.value,)

    stats["casebooks"] = casebooks.count()

    with connection.cursor() as cursor:

        # Create a little data warehouse of prefiltered reporting-ready tables for reuse in this session
        cursor.execute(
            """
        create temp table if not exists casebooks_from_professors as
            select casebook_id from main_contentcollaborator
            inner join main_user u on main_contentcollaborator.user_id = u.id
            inner join main_casebook c on main_contentcollaborator.casebook_id = c.id
            where u.verified_professor is true
                and c.created_at >= %s
                and c.created_at <= %s
                and c.state in %s
            group by casebook_id
            """,
            [start_date, end_date, state],
        )

        cursor.execute(
            """
        create temp table if not exists casebooks_with_multiple_collaborators as
            select casebook_id from main_contentcollaborator
            inner join main_casebook c on main_contentcollaborator.casebook_id = c.id
            where c.created_at >= %s
                and c.created_at <= %s
                and c.state in %s

            group by casebook_id
            having count(user_id) > 1
        """,
            [start_date, end_date, state],
        )

        for source in (
            "CAP",
            "GPO",
        ):
            cursor.execute(
                f"""
                create temp table if not exists casebooks_including_source_{source.lower()} as
                    select casebook_id
                    from main_contentnode
                    inner join main_casebook c on main_contentnode.casebook_id = c.id
                    where resource_type = 'LegalDocument'
                    and resource_id in
                    (
                        select doc.id from main_legaldocument doc
                        inner join main_legaldocumentsource source on source.id = source_id
                        where source.name = %s
                    )
                    and c.created_at >= %s
                    and c.created_at <= %s
                    and state in %s
                    group by casebook_id

                """,
                [source, start_date, end_date, state],
            )

        # Run the specific queries needed for the reports

        # Casebooks including content from Capstone
        cursor.execute(
            """
            select count(*) from main_casebook where main_casebook.id
                in (select * from casebooks_including_source_cap)
            """
        )
        stats["casebooks_cap"] = cursor.fetchone()[0]

        # Casebooks including content from Cap created by verified professors
        cursor.execute(
            """
            select count(*) from main_casebook where main_casebook.id
                in (select * from casebooks_including_source_cap)
                and main_casebook.id in
                   (select * from casebooks_from_professors)
            """
        )
        stats["casebooks_cap_prof"] = cursor.fetchone()[0]

        # Casebooks including content from GPO
        cursor.execute(
            """
            select count(*) from main_casebook where main_casebook.id
                in (select * from casebooks_including_source_gpo)
            """
        )

        stats["casebooks_gpo"] = cursor.fetchone()[0]

        # Casebooks including content from GPO created by verified professors
        cursor.execute(
            """
            select count(*) from main_casebook where main_casebook.id
                in (select * from casebooks_including_source_gpo)
                and main_casebook.id in
                   (select * from casebooks_from_professors)
            """
        )
        stats["casebooks_gpo_prof"] = cursor.fetchone()[0]

        # Casebooks with multiple collaborators
        cursor.execute(
            """
        select count(*) from casebooks_with_multiple_collaborators
        """
        )
        stats["casebooks_with_collaborators"] = cursor.fetchone()[0]

        # Casebooks with multiple collaborators including professors
        cursor.execute(
            """
        select count(*) from main_casebook where main_casebook.id
            in (select * from casebooks_with_multiple_collaborators)
            and main_casebook.id
            in (select * from casebooks_from_professors)
        """
        )
        stats["casebooks_with_collaborators_prof"] = cursor.fetchone()[0]

        # Series
        cursor.execute(
            """
        select count(*) from main_commontitle ct
        inner join main_casebook c on c.id = ct.current_id
        where c.created_at >= %s
              and c.created_at <= %s
              and c.state in %s
        """, [start_date, end_date, state]
        )
        stats["series"] = cursor.fetchone()[0]

        # Series by professors
        # This only checks the most-current title's authorship, but probably sufficient?
        cursor.execute(
            """
        select count(*) from main_commontitle where main_commontitle.current_id
            in (select * from casebooks_from_professors)
        """
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
