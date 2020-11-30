DROP MATERIALIZED VIEW IF EXISTS search_view;
DROP MATERIALIZED VIEW IF EXISTS internal_search_view;
CREATE MATERIALIZED VIEW internal_search_view AS
    -- via app/models/case.rb
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           c.id AS result_id,
           (
                setweight(to_tsvector('english',coalesce(c.name, '')), 'A') ||
                setweight(to_tsvector('english',coalesce(array_to_string(c.citations, ', '),'')), 'A')
            )  AS document,
           jsonb_build_object(
               'display_name', coalesce(c.short_name, c.name),
               'effective_date', effective_date,
               'effective_date_formatted', TO_CHAR(effective_date, 'Month FMDD, YYYY'),
               'citations', array_to_string(c.citations, ', '),
               'jurisdiction', jurisdiction
           ) AS metadata,
           'legal_doc'::text AS category
    FROM
        main_legaldocument c
    GROUP BY c.id
UNION ALL
    -- via app/models/content/casebook.rb
    SELECT
        row_number() OVER (PARTITION BY true) AS id,
        c.id AS result_id,
        (
            setweight(to_tsvector('english',coalesce(c.title, '')), 'A') ||
            setweight(to_tsvector('english',coalesce(string_agg(u.attribution, ', '), '')), 'A') ||
            setweight(to_tsvector('english',coalesce(string_agg(u.affiliation, ', '), '')), 'A') ||
            setweight(to_tsvector('english',coalesce(subtitle, '')), 'D') ||
            setweight(to_tsvector('english',coalesce(headnote, '')), 'D')
        )  AS document,
        jsonb_build_object(
            'title', coalesce(c.title, 'Untitled'),
            'attribution', string_agg(u.attribution, ', '),
            'affiliation', string_agg(u.affiliation, ', '),
            'created_at', c.created_at
        ) AS metadata,
        'casebook'::text AS category
    FROM
        main_casebook c
        LEFT JOIN main_contentcollaborator cc ON cc.casebook_id = c.id AND cc.has_attribution = true
        LEFT JOIN main_user u ON cc.user_id = u.id
    WHERE
        state = 'Public' AND
        u.verified_professor = true
    GROUP BY c.id
UNION ALL
    -- via app/models/user.rb
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           u.id AS result_id,
           (
                setweight(to_tsvector('english',coalesce(u.attribution, '')), 'A')
            )  AS document,
           jsonb_build_object(
               'attribution', u.attribution,
               'affiliation', u.affiliation,
               'casebook_count', count(cb.id)
           ) AS metadata,
           'user'::text AS category
    FROM
        main_user u
        INNER JOIN main_contentcollaborator cc ON cc.user_id = u.id
        INNER JOIN main_casebook cb ON cc.casebook_id = cb.id AND cb.state='Public'
    WHERE
          u.verified_professor = true AND
          u.attribution != ''
    GROUP BY u.id
;
CREATE UNIQUE INDEX search_view_refresh_index ON internal_search_view (result_id, category);
