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
    attribution,
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
    with casebooks_with_changes as (
        select c.id as casebook_id,
            c.state,
            c.created_at,
            main_casebookeditlog.entry_date as entry_date,
            c.updated_at as casebook_date
        from main_casebook c
        left outer join (
            -- Get the largest auto-incrementing id for this casebook from the edit log
            select casebook_id, max(id) as log_id from main_casebookeditlog
            group by casebook_id
        ) most_recent_log_entry on c.id = most_recent_log_entry.casebook_id
        left join main_casebookeditlog on main_casebookeditlog.id = most_recent_log_entry.log_id
        group by c.id, c.created_at, main_casebookeditlog.entry_date, c.updated_at
    )
    select casebook_id, state, created_at,
        case
            when entry_date is null then casebook_date
            else entry_date
        end updated_at
    from casebooks_with_changes
    group by casebook_id, state, created_at, updated_at;


-- Casebooks created by professors
create materialized view if not exists reporting_casebooks_from_professors as
select
    main_contentcollaborator.casebook_id,
    c.state,
    c.created_at,
    c.updated_at
from main_contentcollaborator
inner join reporting_professors p
    on main_contentcollaborator.user_id = p.user_id
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

-- Casebooks by verified professors over time

create materialized view if not exists reporting_professors_with_casebooks_over_time as
select 
    p.user_id, 
    p.attribution,
    p.created_at,
    p.last_login_at,
    extract(year from c.created_at) as created_year,
    count(*) as num_casebooks
from reporting_casebooks c 
    inner join main_contentcollaborator cc on cc.casebook_id = c.casebook_id 
    inner join reporting_professors p on p.user_id = cc.user_id
where c.state in ('Public', 'Revising')
group by p.user_id, p.attribution, p.created_at, p.last_login_at, extract(year from c.created_at);


