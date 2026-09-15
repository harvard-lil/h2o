"""A scheduled refresh must not rebuild the view for unrelated database errors."""

import pytest
from django.db import OperationalError, ProgrammingError, connection
from psycopg2.errors import InsufficientPrivilege

from main.models import SearchIndex

pytestmark = pytest.mark.django_db(transaction=True)


@pytest.fixture
def search_view():
    SearchIndex.create_search_index()
    yield
    with connection.cursor() as cursor:
        cursor.execute("DROP MATERIALIZED VIEW IF EXISTS internal_search_view")


def view_oid():
    with connection.cursor() as cursor:
        cursor.execute("SELECT to_regclass('internal_search_view')::oid")
        return cursor.fetchone()[0]


def test_refresh_creates_missing_view(search_view):
    with connection.cursor() as cursor:
        cursor.execute("DROP MATERIALIZED VIEW internal_search_view")
    SearchIndex.refresh_search_index()
    assert view_oid() is not None


def test_refresh_preserves_existing_view(search_view):
    original = view_oid()
    SearchIndex.refresh_search_index()
    assert view_oid() == original


def test_refresh_does_not_rebuild_when_unique_index_is_missing(search_view):
    original = view_oid()
    with connection.cursor() as cursor:
        cursor.execute("DROP INDEX search_view_refresh_index")
    with pytest.raises(OperationalError, match="Create a unique index"):
        SearchIndex.refresh_search_index()
    assert view_oid() == original


def test_refresh_does_not_rebuild_on_permission_error(mocker):
    error = ProgrammingError("permission denied for materialized view")
    error.__cause__ = InsufficientPrivilege(str(error))
    cursor = mocker.patch("main.models.connection.cursor").return_value.__enter__.return_value
    cursor.execute.side_effect = error
    rebuild = mocker.patch.object(SearchIndex, "create_search_index")
    with pytest.raises(ProgrammingError, match="permission denied"):
        SearchIndex.refresh_search_index()
    rebuild.assert_not_called()
