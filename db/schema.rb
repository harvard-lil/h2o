# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20100603140855) do

  create_table "annotations", :force => true do |t|
    t.integer  "user_id"
    t.integer  "collage_id"
    t.string   "annotation",        :limit => 10240
    t.string   "annotation_start"
    t.string   "annotation_end"
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "annotations", ["ancestors_count"], :name => "index_annotations_on_ancestors_count"
  add_index "annotations", ["annotation_end"], :name => "index_annotations_on_annotation_end"
  add_index "annotations", ["annotation_start"], :name => "index_annotations_on_annotation_start"
  add_index "annotations", ["children_count"], :name => "index_annotations_on_children_count"
  add_index "annotations", ["descendants_count"], :name => "index_annotations_on_descendants_count"
  add_index "annotations", ["hidden"], :name => "index_annotations_on_hidden"
  add_index "annotations", ["parent_id"], :name => "index_annotations_on_parent_id"
  add_index "annotations", ["position"], :name => "index_annotations_on_position"

  create_table "case_citations", :force => true do |t|
    t.integer  "case_id"
    t.string   "volume",     :limit => 200, :null => false
    t.string   "reporter",   :limit => 200, :null => false
    t.string   "page",       :limit => 200, :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "case_citations", ["case_id"], :name => "index_case_citations_on_case_id"
  add_index "case_citations", ["page"], :name => "index_case_citations_on_page"
  add_index "case_citations", ["reporter"], :name => "index_case_citations_on_reporter"
  add_index "case_citations", ["volume"], :name => "index_case_citations_on_volume"

  create_table "case_docket_numbers", :force => true do |t|
    t.integer  "case_id"
    t.string   "docket_number", :limit => 200, :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "case_docket_numbers", ["case_id"], :name => "index_case_docket_numbers_on_case_id"
  add_index "case_docket_numbers", ["docket_number"], :name => "index_case_docket_numbers_on_docket_number"

  create_table "case_jurisdictions", :force => true do |t|
    t.string   "abbreviation", :limit => 150
    t.string   "name",         :limit => 500
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "case_jurisdictions", ["abbreviation"], :name => "index_case_jurisdictions_on_abbreviation"
  add_index "case_jurisdictions", ["name"], :name => "index_case_jurisdictions_on_name"

  create_table "cases", :force => true do |t|
    t.boolean  "current_opinion",                         :default => true
    t.string   "short_name",           :limit => 150,                       :null => false
    t.string   "full_name",            :limit => 500,                       :null => false
    t.date     "decision_date"
    t.string   "author",               :limit => 150
    t.integer  "case_jurisdiction_id"
    t.string   "party_header",         :limit => 10240
    t.string   "lawyer_header",        :limit => 2048
    t.string   "header_html",          :limit => 15360
    t.string   "content",              :limit => 5242880,                   :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cases", ["author"], :name => "index_cases_on_author"
  add_index "cases", ["case_jurisdiction_id"], :name => "index_cases_on_case_jurisdiction_id"
  add_index "cases", ["created_at"], :name => "index_cases_on_created_at"
  add_index "cases", ["current_opinion"], :name => "index_cases_on_current_opinion"
  add_index "cases", ["decision_date"], :name => "index_cases_on_decision_date"
  add_index "cases", ["full_name"], :name => "index_cases_on_full_name"
  add_index "cases", ["short_name"], :name => "index_cases_on_short_name"
  add_index "cases", ["updated_at"], :name => "index_cases_on_updated_at"

  create_table "collages", :force => true do |t|
    t.integer  "user_id"
    t.string   "annotatable_type"
    t.integer  "annotatable_id"
    t.string   "name",              :limit => 250,  :null => false
    t.string   "description",       :limit => 5120
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "collages", ["ancestors_count"], :name => "index_collages_on_ancestors_count"
  add_index "collages", ["annotatable_id"], :name => "index_collages_on_annotatable_id"
  add_index "collages", ["annotatable_type"], :name => "index_collages_on_annotatable_type"
  add_index "collages", ["children_count"], :name => "index_collages_on_children_count"
  add_index "collages", ["created_at"], :name => "index_collages_on_created_at"
  add_index "collages", ["descendants_count"], :name => "index_collages_on_descendants_count"
  add_index "collages", ["hidden"], :name => "index_collages_on_hidden"
  add_index "collages", ["name"], :name => "index_collages_on_name"
  add_index "collages", ["parent_id"], :name => "index_collages_on_parent_id"
  add_index "collages", ["position"], :name => "index_collages_on_position"
  add_index "collages", ["updated_at"], :name => "index_collages_on_updated_at"

  create_table "item_defaults", :force => true do |t|
    t.string   "title"
    t.string   "output_text", :limit => 1024
    t.string   "url",         :limit => 1024
    t.text     "description"
    t.boolean  "active",                      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                      :default => true
  end

  add_index "item_defaults", ["active"], :name => "index_item_defaults_on_active"
  add_index "item_defaults", ["url"], :name => "index_item_defaults_on_url"

  create_table "item_images", :force => true do |t|
    t.string   "title"
    t.string   "output_text", :limit => 1024
    t.string   "url",         :limit => 1024
    t.text     "description"
    t.boolean  "active",                      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                      :default => true
  end

  add_index "item_images", ["active"], :name => "index_item_images_on_active"
  add_index "item_images", ["url"], :name => "index_item_images_on_url"

  create_table "item_texts", :force => true do |t|
    t.string   "title"
    t.string   "output_text", :limit => 1024
    t.string   "url",         :limit => 1024
    t.text     "description"
    t.boolean  "active",                      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                      :default => true
  end

  add_index "item_texts", ["active"], :name => "index_item_texts_on_active"
  add_index "item_texts", ["url"], :name => "index_item_texts_on_url"

  create_table "item_youtubes", :force => true do |t|
    t.string   "title"
    t.string   "output_text", :limit => 1024
    t.string   "url",         :limit => 1024
    t.text     "description"
    t.boolean  "active",                      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                      :default => true
  end

  add_index "item_youtubes", ["active"], :name => "index_item_youtubes_on_active"
  add_index "item_youtubes", ["url"], :name => "index_item_youtubes_on_url"

  create_table "notification_trackers", :force => true do |t|
    t.integer  "rotisserie_discussion_id"
    t.integer  "rotisserie_post_id"
    t.integer  "user_id"
    t.string   "notify_description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "notification_trackers", ["rotisserie_discussion_id"], :name => "index_notification_trackers_on_rotisserie_discussion_id"
  add_index "notification_trackers", ["rotisserie_post_id"], :name => "index_notification_trackers_on_rotisserie_post_id"
  add_index "notification_trackers", ["user_id"], :name => "index_notification_trackers_on_user_id"

  create_table "playlist_items", :force => true do |t|
    t.integer  "playlist_id"
    t.integer  "resource_item_id"
    t.string   "resource_item_type"
    t.boolean  "active",             :default => true
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "playlist_items", ["active"], :name => "index_playlist_items_on_active"
  add_index "playlist_items", ["resource_item_id"], :name => "index_playlist_items_on_resource_item_id"
  add_index "playlist_items", ["resource_item_type"], :name => "index_playlist_items_on_resource_item_type"

  create_table "playlists", :force => true do |t|
    t.string   "title",                                         :null => false
    t.string   "output_text", :limit => 1024
    t.text     "description"
    t.boolean  "active",                      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                      :default => true
  end

  add_index "playlists", ["active"], :name => "index_playlists_on_active"

  create_table "question_instances", :force => true do |t|
    t.string   "name",                    :limit => 250,                 :null => false
    t.integer  "user_id"
    t.integer  "project_id"
    t.string   "password",                :limit => 128
    t.integer  "featured_question_count",                 :default => 2
    t.string   "description",             :limit => 2000
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "question_instances", ["ancestors_count"], :name => "index_question_instances_on_ancestors_count"
  add_index "question_instances", ["children_count"], :name => "index_question_instances_on_children_count"
  add_index "question_instances", ["descendants_count"], :name => "index_question_instances_on_descendants_count"
  add_index "question_instances", ["hidden"], :name => "index_question_instances_on_hidden"
  add_index "question_instances", ["name"], :name => "index_question_instances_on_name", :unique => true
  add_index "question_instances", ["parent_id"], :name => "index_question_instances_on_parent_id"
  add_index "question_instances", ["position"], :name => "index_question_instances_on_position"
  add_index "question_instances", ["project_id", "position"], :name => "index_question_instances_on_project_id_and_position", :unique => true
  add_index "question_instances", ["project_id"], :name => "index_question_instances_on_project_id"
  add_index "question_instances", ["user_id"], :name => "index_question_instances_on_user_id"

  create_table "questions", :force => true do |t|
    t.integer  "question_instance_id"
    t.integer  "user_id"
    t.string   "question",             :limit => 10000,                    :null => false
    t.boolean  "sticky",                                :default => false
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "questions", ["created_at"], :name => "index_questions_on_created_at"
  add_index "questions", ["parent_id"], :name => "index_questions_on_parent_id"
  add_index "questions", ["position"], :name => "index_questions_on_position"
  add_index "questions", ["question_instance_id"], :name => "index_questions_on_question_instance_id"
  add_index "questions", ["sticky"], :name => "index_questions_on_sticky"
  add_index "questions", ["updated_at"], :name => "index_questions_on_updated_at"
  add_index "questions", ["user_id"], :name => "index_questions_on_user_id"

  create_table "roles", :force => true do |t|
    t.string   "name",              :limit => 40
    t.string   "authorizable_type", :limit => 40
    t.integer  "authorizable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "roles", ["authorizable_id"], :name => "index_roles_on_authorizable_id"
  add_index "roles", ["authorizable_type"], :name => "index_roles_on_authorizable_type"
  add_index "roles", ["name"], :name => "index_roles_on_name"

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer  "user_id"
    t.integer  "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "roles_users", ["role_id"], :name => "index_roles_users_on_role_id"
  add_index "roles_users", ["user_id"], :name => "index_roles_users_on_user_id"

  create_table "rotisserie_assignments", :force => true do |t|
    t.integer  "user_id"
    t.integer  "rotisserie_discussion_id"
    t.integer  "rotisserie_post_id"
    t.integer  "round"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rotisserie_assignments", ["rotisserie_discussion_id"], :name => "index_rotisserie_assignments_on_rotisserie_discussion_id"
  add_index "rotisserie_assignments", ["rotisserie_post_id"], :name => "index_rotisserie_assignments_on_rotisserie_post_id"
  add_index "rotisserie_assignments", ["round"], :name => "index_rotisserie_assignments_on_round"
  add_index "rotisserie_assignments", ["user_id"], :name => "index_rotisserie_assignments_on_user_id"

  create_table "rotisserie_discussions", :force => true do |t|
    t.integer  "rotisserie_instance_id"
    t.string   "title",                  :limit => 250,                   :null => false
    t.text     "output"
    t.text     "description"
    t.text     "notes"
    t.integer  "round_length",                          :default => 2
    t.integer  "final_round",                           :default => 2
    t.datetime "start_date"
    t.string   "session_id"
    t.boolean  "active",                                :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                                :default => true
  end

  add_index "rotisserie_discussions", ["active"], :name => "index_rotisserie_discussions_on_active"
  add_index "rotisserie_discussions", ["rotisserie_instance_id"], :name => "index_rotisserie_discussions_on_rotisserie_instance_id"
  add_index "rotisserie_discussions", ["title"], :name => "index_rotisserie_discussions_on_title"

  create_table "rotisserie_instances", :force => true do |t|
    t.string   "title",       :limit => 250,                   :null => false
    t.text     "output"
    t.text     "description"
    t.text     "notes"
    t.string   "session_id"
    t.boolean  "active",                     :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                     :default => true
  end

  add_index "rotisserie_instances", ["title"], :name => "index_rotisserie_instances_on_title", :unique => true

  create_table "rotisserie_posts", :force => true do |t|
    t.integer  "rotisserie_discussion_id"
    t.integer  "round"
    t.string   "title",                    :limit => 250,                   :null => false
    t.text     "output"
    t.string   "session_id"
    t.boolean  "active",                                  :default => true
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                                  :default => true
  end

  add_index "rotisserie_posts", ["active"], :name => "index_rotisserie_posts_on_active"
  add_index "rotisserie_posts", ["parent_id"], :name => "index_rotisserie_posts_on_parent_id"
  add_index "rotisserie_posts", ["position"], :name => "index_rotisserie_posts_on_position"
  add_index "rotisserie_posts", ["rotisserie_discussion_id"], :name => "index_rotisserie_posts_on_rotisserie_discussion_id"
  add_index "rotisserie_posts", ["round"], :name => "index_rotisserie_posts_on_round"

  create_table "rotisserie_trackers", :force => true do |t|
    t.integer  "rotisserie_discussion_id"
    t.integer  "rotisserie_post_id"
    t.integer  "user_id"
    t.string   "notify_description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rotisserie_trackers", ["rotisserie_discussion_id"], :name => "index_rotisserie_trackers_on_rotisserie_discussion_id"
  add_index "rotisserie_trackers", ["rotisserie_post_id"], :name => "index_rotisserie_trackers_on_rotisserie_post_id"
  add_index "rotisserie_trackers", ["user_id"], :name => "index_rotisserie_trackers_on_user_id"

  create_table "sessions", :force => true do |t|
    t.string   "session_id", :null => false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "taggable_type"
    t.string   "context"
    t.datetime "created_at"
  end

  add_index "taggings", ["context"], :name => "index_taggings_on_context"
  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type", "context"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_context"
  add_index "taggings", ["taggable_id"], :name => "index_taggings_on_taggable_id"
  add_index "taggings", ["taggable_type"], :name => "index_taggings_on_taggable_type"
  add_index "taggings", ["tagger_id"], :name => "index_taggings_on_tagger_id"
  add_index "taggings", ["tagger_type"], :name => "index_taggings_on_tagger_type"

  create_table "tags", :force => true do |t|
    t.string "name"
  end

  add_index "tags", ["name"], :name => "index_tags_on_name"

  create_table "users", :force => true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "login"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.string   "persistence_token",                :null => false
    t.integer  "login_count",       :default => 0, :null => false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.string   "last_login_ip"
    t.string   "current_login_ip"
    t.string   "oauth_token"
    t.string   "oauth_secret"
    t.string   "email_address"
    t.string   "tz_name"
  end

  add_index "users", ["email_address"], :name => "index_users_on_email_address"
  add_index "users", ["last_request_at"], :name => "index_users_on_last_request_at"
  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["oauth_token"], :name => "index_users_on_oauth_token"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"
  add_index "users", ["tz_name"], :name => "index_users_on_tz_name"

  create_table "votes", :force => true do |t|
    t.boolean  "vote",          :default => false
    t.integer  "voteable_id"
    t.string   "voteable_type"
    t.integer  "voter_id"
    t.string   "voter_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "votes", ["voteable_id", "voteable_type"], :name => "fk_voteables"
  add_index "votes", ["voter_id", "voter_type", "voteable_id", "voteable_type"], :name => "uniq_one_vote_only", :unique => true
  add_index "votes", ["voter_id", "voter_type"], :name => "fk_voters"

end
