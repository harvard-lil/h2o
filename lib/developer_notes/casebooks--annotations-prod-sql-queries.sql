-- Find the casebook title and id with number of affected annotations in prod sql

SELECT casebook.title, content_nodes.casebook_id, count(content_annotations.id)
FROM "content_nodes" 
inner join content_annotations on content_nodes.id = content_annotations.resource_id
inner join content_nodes as casebook on content_nodes.casebook_id = casebook.id
where content_annotations.created_at >= '2018-10-29'
and "content_nodes"."casebook_id" IS NOT NULL AND "content_nodes"."casebook_id" IS NOT NULL AND "content_nodes"."resource_id" IS NOT NULL
group by content_nodes.casebook_id, casebook.title
order by count(content_annotations.id) desc;

