DROP MATERIALIZED VIEW IF EXISTS search_view;
DROP MATERIALIZED VIEW IF EXISTS internal_search_view;
CREATE MATERIALIZED VIEW internal_search_view AS
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
    SELECT
        row_number() OVER (PARTITION BY true) AS id,
        c.id AS result_id,
        (
            setweight(to_tsvector('english',coalesce(c.title, '')), 'A') ||
            setweight(to_tsvector('english',coalesce(string_agg(u.attribution, ', '), '')), 'A') ||
            setweight(to_tsvector('english',coalesce(string_agg(inst.name, ', '), '')), 'A') ||
            setweight(to_tsvector('english',coalesce(subtitle, '')), 'D') ||
            setweight(to_tsvector('english',coalesce(headnote, '')), 'D') ||
            setweight(to_tsvector('english',coalesce(description, '')), 'A')
        )  AS document,
        jsonb_build_object(
            'title', coalesce(c.title, 'Untitled'),
            'attribution', string_agg(u.attribution, ', '),
            'institution', coalesce(array_agg(inst.name) filter (where inst.name is not null), '{}'),
            'created_at', c.created_at,
            'description', c.description
        ) AS metadata,
        'casebook'::text AS category
    FROM
        main_casebook c
        LEFT JOIN main_contentcollaborator cc ON cc.casebook_id = c.id AND cc.has_attribution = true
        LEFT JOIN main_user u ON cc.user_id = u.id
        LEFT JOIN main_institution inst ON u.institution_id = inst.id
    WHERE
        state IN ('Public','Revising') AND
        u.verified_professor = true AND
        c.listed_publicly = true AND 
        c.id NOT IN (
            -- Exclude older editions of casebooks in series
            SELECT
                ci.id
                FROM main_casebook ci
                JOIN main_commontitle ct ON ci.common_title_id = ct.id
                WHERE ct.current_id != ci.id
            )
    GROUP BY c.id

UNION ALL
    SELECT
           row_number() OVER (PARTITION BY true) AS id,
           u.id AS result_id,
           (
                setweight(to_tsvector('english',coalesce(u.attribution, '')), 'A')
            )  AS document,
           jsonb_build_object(
               'attribution', u.attribution,
               'institution', inst.name,
               'casebook_count', count(cb.id)
           ) AS metadata,
           'user'::text AS category
    FROM
        main_user u
        INNER JOIN main_contentcollaborator cc ON cc.user_id = u.id
        INNER JOIN main_casebook cb ON cc.casebook_id = cb.id AND cb.state='Public'
        LEFT JOIN main_institution inst on u.institution_id = inst.id
        
    WHERE
          u.verified_professor = true AND
          u.attribution != ''
    GROUP BY u.id, inst.id
;
CREATE UNIQUE INDEX search_view_refresh_index ON internal_search_view (result_id, category);
