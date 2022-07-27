-- SQL called by `create_reporting_views.py` to generate nightly reporting tables
drop materialized view if exists reporting_users cascade;
drop materialized view if exists reporting_professors cascade;
drop materialized view if exists reporting_professors_with_casebooks cascade;
drop materialized view if exists reporting_casebooks cascade;
drop materialized view if exists reporting_casebooks_from_professors cascade;
drop materialized view if exists reporting_casebooks_with_multiple_collaborators;
drop materialized view if exists reporting_casebooks_including_source_cap;
drop materialized view if exists reporting_casebooks_including_source_gpo;
drop materialized view if exists reporting_casebooks_series;
drop materialized view if exists reporting_casebooks_series_from_professors;


-- Active users who aren't superusers (admins)
create materialized view if not exists reporting_users as
select
    id as user_id,
    verified_professor,
    attribution,
    created_at,
    last_login_at
from main_user
where is_active is true
    and is_superuser is false;

-- Professors from the reporting pool of users
create materialized view if not exists reporting_professors as
select
    user_id,
    created_at,
    last_login_at
from reporting_users
where verified_professor is true
    and attribution != '';

-- Professors with casebooks
create materialized view if not exists reporting_professors_with_casebooks as
select
    reporting_professors.user_id,
    main_casebook.state,
    main_casebook.created_at,
    reporting_professors.last_login_at
from main_contentcollaborator
inner join reporting_professors
    on main_contentcollaborator.user_id = reporting_professors.user_id
inner join
    main_casebook on main_contentcollaborator.casebook_id = main_casebook.id
group by reporting_professors.user_id, main_casebook.state, main_casebook.created_at, reporting_professors.last_login_at;

-- Casebooks
create materialized view if not exists reporting_casebooks as
select c.id as casebook_id,
    c.state,
    c.created_at,
    greatest(max_entry_date.entry_date, c.updated_at) as updated_at
from main_casebook c
left outer join (
    select casebook_id, greatest(entry_date) as entry_date from main_casebookeditlog
    group by casebook_id, entry_date
) max_entry_date on c.id = max_entry_date.casebook_id
group by c.id, c.created_at, max_entry_date.entry_date
order by greatest(max_entry_date.entry_date, c.updated_at) desc limit 1;

-- Casebooks created by professors
create materialized view if not exists reporting_casebooks_from_professors as
select
    main_contentcollaborator.casebook_id,
    c.state,
    c.created_at,
    c.updated_at
from main_contentcollaborator
inner join reporting_professors
    on main_contentcollaborator.user_id = reporting_professors.user_id
inner join
    reporting_casebooks c on main_contentcollaborator.casebook_id = c.casebook_id
group by main_contentcollaborator.casebook_id, c.state, c.created_at, c.updated_at;

-- Casebooks with multiple collaborators, at least one of whom is a professor
create materialized view if not exists reporting_casebooks_with_multiple_collaborators as
select
    main_contentcollaborator.casebook_id,
    reporting_casebooks.state,
    reporting_casebooks.created_at,
    reporting_casebooks.updated_at
from main_contentcollaborator
inner join
    reporting_casebooks on main_contentcollaborator.casebook_id = reporting_casebooks.casebook_id
where main_contentcollaborator.casebook_id in
    (
        select casebook_id
        from main_contentcollaborator where has_attribution is true
    )
group by main_contentcollaborator.casebook_id, reporting_casebooks.state, reporting_casebooks.created_at,
    reporting_casebooks.updated_at
having count(user_id) > 1;

-- Casebooks with any content derived from CAP
create materialized view if not exists reporting_casebooks_including_source_cap as
select
    c.casebook_id,
    c.state,
    c.created_at,
    c.updated_at
from main_contentnode
inner join reporting_casebooks as c on main_contentnode.casebook_id = c.casebook_id
where resource_type = 'LegalDocument'
    and resource_id in
    (
        select doc.id from main_legaldocument as doc
        inner join main_legaldocumentsource as source on source.id = source_id
        where source.name = 'CAP'
    )
group by c.casebook_id, c.state, c.created_at, c.updated_at;

-- Casebooks with any content derived from GPO
create materialized view if not exists reporting_casebooks_including_source_gpo as
select
    c.casebook_id,
    c.state,
    c.created_at,
    c.updated_at
from main_contentnode
inner join reporting_casebooks as c on main_contentnode.casebook_id = c.casebook_id
where resource_type = 'LegalDocument'
    and resource_id in
    (
        select doc.id from main_legaldocument as doc
        inner join main_legaldocumentsource as source on source.id = source_id
        where source.name = 'GPO'
    )
group by c.casebook_id, c.state, c.created_at, c.updated_at;

-- Casebooks that are part of a series
create materialized view if not exists reporting_casebooks_series as
select
    c.casebook_id,
    c.state,
    c.created_at,
    c.updated_at
from main_commontitle
    inner join reporting_casebooks c on c.casebook_id = main_commontitle.current_id;

-- Casebooks that are part of a series by professors
create materialized view if not exists reporting_casebooks_series_from_professors as
select
    c.casebook_id,
    c.state,
    c.created_at,
    c.updated_at
from main_commontitle
    inner join reporting_casebooks_from_professors c on c.casebook_id = main_commontitle.current_id;

