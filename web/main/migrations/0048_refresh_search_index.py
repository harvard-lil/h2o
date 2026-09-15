from pathlib import Path

from django.db import migrations


# Bring fresh installs from 0005's historical view to this version's definition.
# Existing deployments may already match because deploys rebuild the view separately.
SQL = Path(__file__).with_name("0048_search_index.sql").read_text()
VIEW_QUERY, INDEX_SQL = SQL.split("CREATE MATERIALIZED VIEW internal_search_view AS", 1)[
    1
].split("CREATE UNIQUE INDEX", 1)
INDEX_SQL = "CREATE UNIQUE INDEX" + INDEX_SQL


def refresh_search_index(apps, schema_editor):
    # Let PostgreSQL normalize both definitions on the same server. A temporary
    # ordinary view parses the frozen query without executing it or storing rows.
    with schema_editor.connection.cursor() as cursor:
        cursor.execute("CREATE TEMP VIEW migration_0048_expected_search AS " + VIEW_QUERY)
        cursor.execute(
            """
            SELECT c.relispopulated,
                   pg_get_viewdef(c.oid) =
                       pg_get_viewdef('pg_temp.migration_0048_expected_search'::regclass)
            FROM pg_class c
            WHERE c.oid = to_regclass('internal_search_view') AND c.relkind = 'm'
            """
        )
        existing = cursor.fetchone()
        cursor.execute("DROP VIEW pg_temp.migration_0048_expected_search")
        if existing is None or not existing[1]:
            cursor.execute(SQL)
            return

        # Preserve the materialized data when only its refresh index needs repair.
        cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1 FROM pg_index i
                JOIN pg_class c ON c.oid = i.indrelid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.oid = 'internal_search_view'::regclass
                  AND i.indisvalid AND i.indisready
                  AND pg_get_indexdef(i.indexrelid) = format(
                      'CREATE UNIQUE INDEX search_view_refresh_index ON %I.%I '
                      'USING btree (result_id, category)', n.nspname, c.relname
                  )
            )
            """
        )
        if not cursor.fetchone()[0]:
            cursor.execute("DROP INDEX IF EXISTS search_view_refresh_index")
            cursor.execute(INDEX_SQL)
        if not existing[0]:
            cursor.execute("REFRESH MATERIALIZED VIEW internal_search_view")


class Migration(migrations.Migration):
    dependencies = [("main", "0047_auto_20240516_1754")]

    operations = [
        migrations.RunPython(refresh_search_index, reverse_code=migrations.RunPython.noop),
    ]
