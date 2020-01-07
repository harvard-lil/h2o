DROP MATERIALIZED VIEW IF EXISTS search_view;
CREATE MATERIALIZED VIEW search_view AS
    -- via app/models/case.rb
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           c.id AS result_id,
           (
                setweight(to_tsvector(coalesce(c.name, '')), 'A') ||
                setweight(to_tsvector(coalesce(c.name_abbreviation, '')), 'D') ||
                setweight(to_tsvector(coalesce(docket_number, '')), 'D') ||
                setweight(to_tsvector(string_agg(cite, ', ')), 'A') ||
                setweight(to_tsvector(coalesce(min(case_courts.name), '')), 'D')
            )  AS document,
           jsonb_build_object(
               'display_name', coalesce(c.name_abbreviation, c.name),
               'decision_date', decision_date,
               'decision_date_formatted', TO_CHAR(decision_date, 'Month FMDD, YYYY'),
               'citations', string_agg(cite, ', ')
           ) AS metadata,
           'case'::text AS category
    FROM
        cases c
        LEFT JOIN (
            select id as case_id, jsonb_array_elements(citations) ->> 'cite' as cite from cases
        ) as citations on citations.case_id = c.id
        LEFT JOIN case_courts ON c.case_court_id = case_courts.id
    WHERE
        c.public = true
    GROUP BY c.id
UNION ALL
    -- via app/models/content/casebook.rb
    SELECT
        row_number() OVER (PARTITION BY true) AS id,
        c.id AS result_id,
        (
            setweight(to_tsvector(coalesce(c.title, '')), 'A') ||
            setweight(to_tsvector(coalesce(string_agg(u.attribution, ', '), '')), 'A') ||
            setweight(to_tsvector(coalesce(string_agg(u.affiliation, ', '), '')), 'A') ||
            setweight(to_tsvector(coalesce(subtitle, '')), 'D') ||
            setweight(to_tsvector(coalesce(headnote, '')), 'D')
        )  AS document,
        jsonb_build_object(
            'title', coalesce(c.title, 'Untitled'),
            'attribution', string_agg(u.attribution, ', '),
            'affiliation', string_agg(u.affiliation, ', '),
            'created_at', c.created_at
        ) AS metadata,
        'casebook'::text AS category
    FROM
        content_nodes c
        LEFT JOIN content_collaborators cc ON cc.content_id = c.id AND cc.role = 'owner' AND cc.has_attribution = true
        LEFT JOIN users u ON cc.user_id = u.id
    WHERE
        casebook_id IS NULL AND
        public = true AND
        u.verified_professor = true
    GROUP BY c.id
UNION ALL
    -- via app/models/user.rb
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           u.id AS result_id,
           (
                setweight(to_tsvector(coalesce(u.attribution, '')), 'A')
            )  AS document,
           jsonb_build_object(
               'attribution', u.attribution,
               'affiliation', u.affiliation,
               'casebook_count', count(cn.id)
           ) AS metadata,
           'user'::text AS category
    FROM
        users u
        INNER JOIN content_collaborators cc ON cc.user_id = u.id AND cc.role = 'owner'
        INNER JOIN content_nodes cn ON cc.content_id = cn.id AND cn.public = TRUE
    WHERE
          u.verified_professor = true AND
          u.attribution != ''
    GROUP BY u.id
;
CREATE UNIQUE INDEX search_view_refresh_index ON search_view (result_id, category);

-- -- get search results
-- SELECT category, result_id, metadata
-- FROM search_view
-- WHERE
--     document @@ to_tsquery('court')
--     AND category = 'case'
-- ORDER BY ts_rank(document,to_tsquery('court')) desc, result_id;
--
-- -- get search counts
-- SELECT category, count(*)
-- FROM search_view
-- WHERE document @@ to_tsquery('court')
-- GROUP BY category;
--
-- --   (this could be a single query for multiple facets in postgres 9.6, using array_to_tsvector and ts_stat --
-- --    see https://roamanalytics.com/2019/04/16/faceted-search-with-postgres-using-tsvector/ )
-- -- get a single facet
-- SELECT DISTINCT metadata->>'attribution'
-- FROM search_view
-- WHERE
--     document @@ to_tsquery('court')
--     AND category = 'casebook';

