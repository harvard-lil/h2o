## Translate playlists notes

These are the instructions on how to translate playlists into casebooks from [this file](https://docs.google.com/spreadsheets/d/1gHHsqbiZNxeYeWApM7GhU4L8wiZuIJP3EvCd_hXk8xk/edit?usp=sharing). Note that these ids were pulled to create the playlist id array. Some of the numbers in the google sheet aren't the most recent version of that playlist, so the spreadsheet and array don't exactly match. This file was last updated 11/14/17 - any playlists added to this file after that date are not included in this array.

1. `rake db:schema:load` clear the database and rebuild the sceme
1. Make sure you have the `h2o_prod-data.dump` file in your root directory.
1. `pg_restore --verbose --clean --no-acl --no-owner -U h2oadmin -h [aws link] -d h2o ~/h2o_prod-data.dump` port the data dump into the database
  1. (for running locally: `pg_restore --verbose --clean --no-acl --no-owner -h localhost -d h2o_dev ~/h2o_prod-data.dump `)
1. Delete users that don't have emails
  1. `User.where(email_address: nil).destroy_all`
1. `rake db:migrate`
1. `rails c`
1. Fix annotation data
  1. Backfill collage_id from annotated_object_id
    `annotations = Migrate::Annotation.where(collage_id: nil)
     annotations.each do |annotation|
       annotation.update(collage_id: annotation.annotated_item_id)
     end`
  1. Remove annotation duplicates
  `duplicates = Migrate::Annotation.select(:collage_id, :xpath_start, :xpath_end).group(:collage_id, :xpath_start, :xpath_end).having("count(*) > 1").size`

  `duplicates.each do |attrs, count|
    collage_id, xpath_start, xpath_end = attrs
    duplicates = Migrate::Annotation.where(
      collage_id: collage_id,
      xpath_start: xpath_start,
      xpath_end: xpath_end
    )[1..-1]
    duplicates.each(&:destroy)
  end`

1. `playlist_ids = [66, 603, 633, 711, 986, 1324, 1369, 1510, 1844, 1862, 1889, 1923, 1995, 3762, 5094, 5143, 5555, 5804, 5866, 5876, 7072, 7337, 7384, 7390, 7399, 7446, 8624, 8770, 9141, 9156, 9157, 9267, 9364, 9504, 9623, 10007, 10033, 10065, 10236, 10237, 10572, 10609, 11114, 11492, 11800, 12489, 12716, 12826, 12864, 12865, 12922, 13023, 13034, 13086, 14454, 17803, 19763, 20336, 20370, 20406, 20443, 20493, 20630, 20861, 21225, 21529, 21898, 21913, 22180, 22188, 22189, 22235, 22269, 22363, 22368, 22568, 24353, 24419, 24704, 24739, 25022, 25421, 25606, 25698, 25965, 26039, 26057, 26074, 26143, 26147, 26221, 26241, 26271, 26372, 26401, 26452, 26559, 27297, 27438, 27790, 27819, 27845, 28015, 28148, 28286, 50966, 51028, 51291, 51531, 51575, 51676, 51703, 51759, 51760, 51770, 51792, 51938, 51971, 52383, 52511, 52719]`
1. Make sure in all annotation annotated_item_id and collage_id match
1. `Migrate::PlaylistItem.find(2445).destroy` this item was deleted by the author and no longer exists
1. `Migrate::Playlist.find(playlist_ids).map &:migrate`
1. Get rid of users who don't have published books
  `user_ids = []
  Content::Casebook.all.each do |casebook|
    user_ids << casebook.owner.id
  end
  User.where.not(id: [user_ids]).destroy_all`
1. `rails sunspot:solr:reindex`