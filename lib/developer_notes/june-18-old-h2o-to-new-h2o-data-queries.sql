1. Create db
createdb h2o_prod
psql -d h2o_prod < ../[sql-dump-file]
psql h2o_prod

-------------
2. Create and fill migration tables

CREATE TABLE migration_playlists (
  id integer unique
);

INSERT INTO migration_playlists (id)
VALUES (53441), (53940), (22180);

CREATE TABLE migration_playlist_items (
  id integer unique,
  actual_object_type character varying(255),
  actual_object_id integer,
  playlist_id integer
);

# insert top level playlist items
INSERT INTO migration_playlist_items
SELECT id, actual_object_type, actual_object_id, playlist_id from playlist_items where playlist_id in (select id from migration_playlists);

#insert all lower level playlist items, and don't insert if already exists. Run this 15 times until the count of the table doesn't inscreare 
INSERT INTO migration_playlist_items
SELECT id, actual_object_type, actual_object_id, playlist_id from playlist_items 
WHERE playlist_id in (select actual_object_id from migration_playlist_items where actual_object_type = 'Playlist')
ON CONFLICT (id) do nothing;

# add the playlist object to playlist table
INSERT INTO migration_playlists
SELECT actual_object_id from migration_playlist_items 
WHERE actual_object_type = 'Playlist'
ON CONFLICT (id) do nothing;

CREATE TABLE migration_medias (
  id integer
);

CREATE TABLE migration_text_blocks (
  id integer
);

CREATE TABLE migration_defaults (
  id integer
);

CREATE TABLE migration_collages (
  id integer
);


INSERT INTO migration_medias
SELECT actual_object_id from migration_playlist_items where actual_object_type = 'Media';

INSERT INTO migration_collages
SELECT actual_object_id from migration_playlist_items where actual_object_type = 'Collage';

INSERT INTO migration_text_blocks select annotatable_id from collages where id in (select id from migration_collages) and annotatable_type = 'TextBlock';

INSERT INTO migration_text_blocks select actual_object_id from playlist_items where id in (select id from migration_playlist_items where actual_object_type = 'TextBlock');

INSERT INTO migration_defaults
SELECT actual_object_id from migration_playlist_items where actual_object_type = 'Default';


CREATE TABLE migration_annotations (id integer);

INSERT INTO migration_annotations
SELECT id from annotations 
WHERE annotated_item_id in (select id from migration_collages) or annotated_item_id in (select id from migration_text_blocks);

------
4. export playlists to file in posgres root path 

COPY (select * from playlists where id in (select id from migration_playlists)) TO '/usr/local/var/postgres/playlists.csv' DELIMITER ',' CSV HEADER;

COPY (select * from playlist_items where id in (select id from migration_playlist_items)) TO '/usr/local/var/postgres/playlist_items.csv' DELIMITER ',' CSV HEADER;

COPY (select * from collages where id in (select id from migration_collages)) TO '/usr/local/var/postgres/collages.csv' DELIMITER ',' CSV HEADER;

COPY (select * from text_blocks where id in (select id from migration_text_blocks)) TO '/usr/local/var/postgres/text_blocks.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8';

COPY (select * from defaults where id in (select id from migration_defaults)) TO '/usr/local/var/postgres/defaults.csv' DELIMITER ',' CSV HEADER;

COPY (select * from medias where id in (select id from migration_medias)) TO '/usr/local/var/postgres/medias.csv' DELIMITER ',' CSV HEADER;

COPY (select * from annotations where id in (select id from migration_annotations)) TO '/usr/local/var/postgres/annotations.csv' DELIMITER ',' CSV HEADER;

------

5. Import Data

DELETE FROM playlists;
DELETE FROM playlist_items;
DELETE FROM collages;
DELETE FROM medias;
DELETE FROM annotations;


\COPY playlists FROM '/usr/local/var/postgres/playlists.csv' WITH CSV HEADER;
\COPY playlist_items FROM '/usr/local/var/postgres/playlist_items.csv' WITH CSV HEADER;
\COPY collages FROM '/usr/local/var/postgres/collages.csv' WITH CSV HEADER;
\COPY annotations FROM '/usr/local/var/postgres/annotations.csv' WITH CSV HEADER;
\COPY medias FROM '/usr/local/var/postgres/medias.csv' WITH CSV HEADER;

-- Need to add columns into user file `image_file_name,image_content_type,image_file_size,image_updated_at,verified_professor,professor_verification_requested`

-------

6. Update primary

csv = CSV.read('/usr/local/var/postgres/defaults.csv', headers: true, encoding: 'windows-1251:utf-8')
csv.each do |row|
  link = row.to_hash
  playlist_items = Migrate::PlaylistItem.where(actual_object_id: link["id"], actual_object_type: "Default")
  link.delete("id")
  new_link = Default.create(link)
  playlist_items.map {|item| item.update(actual_object_id: new_link.id)}
end

csv = CSV.read('/usr/local/var/postgres/text_blocks.csv', headers: true, encoding: 'windows-1251:utf-8')
csv.each do |row|
  text_block = row.to_hash
  collages = Migrate::Collage.where(annotatable_id: text_block["id"], annotatable_type: "TextBlock")
  playlist_items = Migrate::PlaylistItem.where(actual_object_type: "TextBlock", actual_object_id: text_block["id"])
  text_block.delete("id")
  if text_block[:created_via_import].nil?
    text_block[:created_via_import] = 'f'
  end
  if text_block[:version].nil?
    text_block[:version] = 1
  end
  if text_block[:enable_feedback].nil?
    text_block[:enable_feedback] = false
  end
  if text_block[:enable_discussions].nil?
    text_block[:enable_discussions] = false
  end
  if text_block[:enable_responses].nil?
    text_block[:enable_responses] = false
  end

  new_text_block = TextBlock.create(text_block)

  if collages.present?
    collages.map {|collage| collage.update(annotatable_id: new_text_block.id)}
  elsif playlist_items.present?
    playlist_items.map {|item| item.update(actual_object_id: new_text_block.id)}
  end  
end

-----

7. Migrating 

playlist_ids = [53441, 53940, 22180]

Migrate::Playlist.find(playlist_ids).map &:migrate

casebooks_to_playlists = {}
playlist_ids.each do |playlist_id| 
  casebook = Content::Casebook.where(playlist_id: playlist_id).where(ancestry: nil).first
  casebooks_to_playlists[casebook.id] = playlist_id
end
