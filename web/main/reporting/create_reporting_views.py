from pathlib import Path
from django.db import connection

from ..models import Casebook


# "Published" state matches logic in the front end, which includes casebooks under revision
PUBLISHED_CASEBOOKS = (
    Casebook.LifeCycle.PUBLISHED.value,
    Casebook.LifeCycle.REVISING.value,
)
ALL_STATES = tuple(tag.value for tag in Casebook.LifeCycle)

OLDEST_YEAR = 20  # How far back in time we'll go

VIEW_LIST = (
    "reporting_professors_with_casebooks",
    "reporting_casebooks_from_professors",
    "reporting_casebooks_with_multiple_collaborators",
    "reporting_casebooks_including_source_cap",
    "reporting_casebooks_including_source_gpo",
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
