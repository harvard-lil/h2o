"""Migration 0048 preserves current data and repairs older search definitions."""

from importlib import import_module

import pytest
from django.db import connection

migration = import_module("main.migrations.0048_refresh_search_index")
pytestmark = pytest.mark.django_db


def apply_migration():
    with connection.schema_editor() as editor:
        migration.refresh_search_index(None, editor)


def view_storage():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT oid, relfilenode, relispopulated FROM pg_class "
            "WHERE oid = to_regclass('internal_search_view')"
        )
        return cursor.fetchone()


def test_current_view_and_index_are_untouched():
    with connection.cursor() as cursor:
        cursor.execute(migration.SQL)
        cursor.execute("SELECT 'search_view_refresh_index'::regclass::oid")
        index_oid = cursor.fetchone()[0]
    original = view_storage()
    apply_migration()
    assert view_storage() == original
    with connection.cursor() as cursor:
        cursor.execute("SELECT 'search_view_refresh_index'::regclass::oid")
        assert cursor.fetchone()[0] == index_oid


def test_outdated_definition_is_replaced():
    with connection.cursor() as cursor:
        cursor.execute(
            migration.SQL.replace("c.listed_publicly = true", "c.listed_publicly = false")
        )
    original = view_storage()
    apply_migration()
    assert view_storage()[0] != original[0]
    updated = view_storage()
    apply_migration()
    assert view_storage() == updated


@pytest.mark.parametrize("incorrect_index", [False, True])
def test_index_repair_preserves_materialized_data(incorrect_index):
    with connection.cursor() as cursor:
        cursor.execute(migration.SQL)
        cursor.execute("DROP INDEX search_view_refresh_index")
        if incorrect_index:
            cursor.execute("CREATE INDEX search_view_refresh_index ON internal_search_view (id)")
    original = view_storage()
    apply_migration()
    assert view_storage() == original
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT indisunique, indisvalid FROM pg_index "
            "WHERE indexrelid = 'search_view_refresh_index'::regclass"
        )
        assert cursor.fetchone() == (True, True)


def test_missing_view_is_created():
    with connection.cursor() as cursor:
        cursor.execute("DROP MATERIALIZED VIEW IF EXISTS internal_search_view")
    apply_migration()
    assert view_storage()[2] is True


def test_unpopulated_view_is_refreshed():
    with connection.cursor() as cursor:
        cursor.execute(migration.SQL)
        cursor.execute("REFRESH MATERIALIZED VIEW internal_search_view WITH NO DATA")
    original = view_storage()
    assert original[2] is False
    apply_migration()
    assert view_storage()[0] == original[0]
    assert view_storage()[2] is True
