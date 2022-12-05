DROP MATERIALIZED VIEW IF EXISTS tmp_fts_search_view;
DROP MATERIALIZED VIEW IF EXISTS tmp_fts_internal_search_view;
CREATE MATERIALIZED VIEW tmp_fts_internal_search_view AS
    -- separate category for full-text search of legal documents
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           c.id AS result_id,
           false AS is_instructional_material,
           (
                setweight(to_tsvector('english',coalesce(c.content, '')), 'D')
            )  AS document,
           jsonb_build_object(
               'display_name', coalesce(c.short_name, c.name),
               'effective_date', effective_date,
               'effective_date_formatted', TO_CHAR(effective_date, 'Month FMDD, YYYY'),
               'citations', array_to_string(c.citations, ';; '),
               'jurisdiction', jurisdiction
           ) AS metadata,
           'legal_doc_fulltext'::text AS category
    FROM
        main_legaldocument c
    GROUP BY c.id
UNION ALL
    -- separate category for full-text search of textblocks
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           t.id AS result_id,
           cn.is_instructional_material AS is_instructional_material,
           (
                setweight(to_tsvector('english',coalesce(t.content, '')), 'D') ||
                setweight(to_tsvector('english',coalesce(t.name, '')), 'A') ||
                setweight(to_tsvector('english',coalesce(t.description, '')), 'C')
            )  AS document,
           jsonb_build_object(
               'name', t.name,
               'description', t.description,
               'ordinals', array_to_string(cn.ordinals, '.'),
               'casebook_id', cn.casebook_id
           ) AS metadata,
           'textblock'::text AS category
    FROM
        main_textblock t
        INNER JOIN main_contentnode cn ON cn.resource_id = t.id AND cn.resource_type = 'TextBlock'
    GROUP BY t.id, cn.id
UNION ALL
    -- Sections effectively only have titles, so limit populating the index to that field
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           cn.id AS result_id,
           cn.is_instructional_material AS is_instructional_material,
           (
                setweight(to_tsvector('english', coalesce(cn.title, '')), 'A')
            )  AS document,
           jsonb_build_object(
               'name', cn.title,
               'ordinals', array_to_string(cn.ordinals, '.'),
               'casebook_id', cn.casebook_id
           ) AS metadata,
           'section'::text AS category
    FROM
        main_contentnode cn
        WHERE (cn.resource_type = 'Section' or cn.resource_type ='' or cn.resource_type is null )
UNION ALL
    -- separate category for searching through links
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           l.id AS result_id,
           false AS is_instructional_material,
           (
                setweight(to_tsvector('english',coalesce(l.url, '')), 'B') ||
                setweight(to_tsvector('english',coalesce(l.name, '')), 'A') ||
                setweight(to_tsvector('english',coalesce(l.description, '')), 'C')
            )  AS document,
           jsonb_build_object(
               'name', coalesce(l.name, cn.title),
               'url', l.url,
               'description', l.description,
               'ordinals', array_to_string(cn.ordinals, '.'),
               'casebook_id', cn.casebook_id
           ) AS metadata,
           'link'::text AS category
    FROM
        main_link l
        INNER JOIN main_contentnode cn ON cn.resource_id = l.id AND cn.resource_type = 'Link'
    GROUP BY l.id, cn.id
;
DROP MATERIALIZED VIEW IF EXISTS fts_search_view;
DROP MATERIALIZED VIEW IF EXISTS fts_internal_search_view;
ALTER MATERIALIZED VIEW IF EXISTS tmp_fts_search_view RENAME to fts_search_view;
ALTER MATERIALIZED VIEW IF EXISTS tmp_fts_internal_search_view RENAME to fts_internal_search_view;
CREATE UNIQUE INDEX fts_search_view_refresh_index ON fts_internal_search_view (result_id, category);
DROP MATERIALIZED VIEW IF EXISTS tmp_fts_search_view;
DROP MATERIALIZED VIEW IF EXISTS tmp_fts_internal_search_view;