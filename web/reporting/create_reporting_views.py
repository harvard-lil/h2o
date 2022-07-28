from pathlib import Path
from django.db import connection

from main.models import Casebook


# "Published" state matches logic in the front end, which includes casebooks under revision
PUBLISHED_CASEBOOKS = (
    Casebook.LifeCycle.PUBLISHED.value,
    Casebook.LifeCycle.REVISING.value,
)
# Don't include "previous saves" as they aren't useful for reporting
ALL_STATES = (
    Casebook.LifeCycle.PUBLISHED.value,
    Casebook.LifeCycle.REVISING.value,
    Casebook.LifeCycle.PRIVATELY_EDITING.value,
    Casebook.LifeCycle.NEWLY_CLONED.value,
    Casebook.LifeCycle.ARCHIVED.value,
    Casebook.LifeCycle.REVISING.value,
)

OLDEST_YEAR = 20  # How far back in time we'll go

VIEW_LIST = (
    "reporting_users",
    "reporting_professors",
    "reporting_professors_with_casebooks",
    "reporting_casebooks",
    "reporting_casebooks_from_professors",
    "reporting_casebooks_with_multiple_collaborators",
    "reporting_casebooks_including_source_cap",
    "reporting_casebooks_including_source_gpo",
    "reporting_casebooks_series",
    "reporting_casebooks_series_from_professors",
)


def create() -> None:
    """Create a little data warehouse of prefiltered reporting-ready tables for reuse in this session.
    This logic should match what's used in `create_search_index.sql` unless otherwise annotated."""

    with connection.cursor() as cursor:
        sql = (Path(__file__).resolve().parent / "sql/reporting.sql").read_text()
        cursor.execute(sql)


def refresh() -> None:
    with connection.cursor() as cursor:

        for view in VIEW_LIST:
            cursor.execute(f"refresh materialized view {view}")
