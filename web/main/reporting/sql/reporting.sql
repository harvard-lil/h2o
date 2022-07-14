-- SQL called by `create_reporting_views.py` to generate nightly reporting tables

drop materialized view if exists reporting_professors_with_casebooks;
drop materialized view if exists reporting_casebooks_from_professors;
drop materialized view if exists reporting_casebooks_with_multiple_collaborators;
drop materialized view if exists reporting_casebooks_including_source_cap;
drop materialized view if exists reporting_casebooks_including_source_gpo;

create materialized view if not exists reporting_professors_with_casebooks as
select
    user_id,
    main_casebook.state,
    main_casebook.created_at
from main_contentcollaborator
inner join main_user on main_contentcollaborator.user_id = main_user.id
inner join
    main_casebook on main_contentcollaborator.casebook_id = main_casebook.id
where main_user.verified_professor is true
    and main_user.attribution != ''
group by user_id, main_casebook.state, main_casebook.created_at;

create materialized view if not exists reporting_casebooks_from_professors as
select
    casebook_id,
    main_casebook.state,
    main_casebook.created_at
from main_contentcollaborator
inner join main_user on main_contentcollaborator.user_id = main_user.id
inner join
    main_casebook on main_contentcollaborator.casebook_id = main_casebook.id
where main_user.verified_professor is true
    and main_contentcollaborator.has_attribution is true
group by casebook_id, main_casebook.state, main_casebook.created_at;


create materialized view if not exists reporting_casebooks_with_multiple_collaborators as
select
    casebook_id,
    main_casebook.state,
    main_casebook.created_at
from main_contentcollaborator
inner join
    main_casebook on main_contentcollaborator.casebook_id = main_casebook.id
where casebook_id in
    (
        select casebook_id
        from main_contentcollaborator where has_attribution is true
    )
group by casebook_id, main_casebook.state, main_casebook.created_at
having count(user_id) > 1;

create materialized view if not exists reporting_casebooks_including_source_cap as
select
    casebook_id,
    c.state,
    c.created_at
from main_contentnode
inner join main_casebook as c on main_contentnode.casebook_id = c.id
where resource_type = 'LegalDocument'
    and resource_id in
    (
        select doc.id from main_legaldocument as doc
        inner join main_legaldocumentsource as source on source.id = source_id
        where source.name = 'CAP'
    )
group by casebook_id, c.state, c.created_at;

create materialized view if not exists reporting_casebooks_including_source_gpo as
select
    casebook_id,
    c.state,
    c.created_at
from main_contentnode
inner join main_casebook as c on main_contentnode.casebook_id = c.id
where resource_type = 'LegalDocument'
    and resource_id in
    (
        select doc.id from main_legaldocument as doc
        inner join main_legaldocumentsource as source on source.id = source_id
        where source.name = 'GPO'
    )
group by casebook_id, c.state, c.created_at;
