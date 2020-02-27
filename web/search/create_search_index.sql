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
                setweight(to_tsvector(coalesce(string_agg(cite, ', '),'')), 'A') ||
                setweight(to_tsvector(coalesce(min(main_casecourt.name), '')), 'D')
            )  AS document,
           jsonb_build_object(
               'display_name', coalesce(c.name_abbreviation, c.name),
               'decision_date', decision_date,
               'decision_date_formatted', TO_CHAR(decision_date, 'Month FMDD, YYYY'),
               'citations', string_agg(cite, ', ')
           ) AS metadata,
           'case'::text AS category
    FROM
        main_case c
        LEFT JOIN (
            select id as case_id, jsonb_array_elements(citations) ->> 'cite' as cite from main_case
        ) as citations on citations.case_id = c.id
        LEFT JOIN main_casecourt ON c.case_court_id = main_casecourt.id
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
        main_contentnode c
        LEFT JOIN main_contentcollaborator cc ON cc.content_id = c.id AND cc.has_attribution = true
        LEFT JOIN main_user u ON cc.user_id = u.id
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
        main_user u
        INNER JOIN main_contentcollaborator cc ON cc.user_id = u.id
        INNER JOIN main_contentnode cn ON cc.content_id = cn.id AND cn.public = TRUE
    WHERE
          u.verified_professor = true AND
          u.attribution != ''
    GROUP BY u.id
;
CREATE UNIQUE INDEX search_view_refresh_index ON search_view (result_id, category);
