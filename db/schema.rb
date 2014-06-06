# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140606175239) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "annotations", force: true do |t|
    t.integer  "collage_id"
    t.string   "annotation",            limit: 10240
    t.string   "annotation_start"
    t.string   "annotation_end"
    t.integer  "word_count"
    t.string   "annotated_content",     limit: 1048576
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ancestry"
    t.boolean  "public",                                default: true
    t.boolean  "active",                                default: true
    t.integer  "annotation_word_count"
    t.integer  "pushed_from_id"
    t.boolean  "cloned",                                default: false, null: false
    t.integer  "user_id",                               default: 0,     null: false
    t.string   "xpath_start"
    t.string   "xpath_end"
    t.integer  "start_offset",                          default: 0,     null: false
    t.integer  "end_offset",                            default: 0,     null: false
    t.integer  "linked_collage_id"
  end

  add_index "annotations", ["active"], name: "index_annotations_on_active", using: :btree
  add_index "annotations", ["ancestry"], name: "index_annotations_on_ancestry", using: :btree
  add_index "annotations", ["annotation_end"], name: "index_annotations_on_annotation_end", using: :btree
  add_index "annotations", ["annotation_start"], name: "index_annotations_on_annotation_start", using: :btree
  add_index "annotations", ["public"], name: "index_annotations_on_public", using: :btree

  create_table "brain_busters", force: true do |t|
    t.string "question"
    t.string "answer"
  end

  create_table "bulk_uploads", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "has_errors"
    t.integer  "delayed_job_id"
  end

  create_table "case_citations", force: true do |t|
    t.integer  "case_id"
    t.string   "volume",     limit: 200, null: false
    t.string   "reporter",   limit: 200, null: false
    t.string   "page",       limit: 200, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "case_citations", ["case_id"], name: "index_case_citations_on_case_id", using: :btree
  add_index "case_citations", ["page"], name: "index_case_citations_on_page", using: :btree
  add_index "case_citations", ["reporter"], name: "index_case_citations_on_reporter", using: :btree
  add_index "case_citations", ["volume"], name: "index_case_citations_on_volume", using: :btree

  create_table "case_docket_numbers", force: true do |t|
    t.integer  "case_id"
    t.string   "docket_number", limit: 200, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "case_docket_numbers", ["case_id"], name: "index_case_docket_numbers_on_case_id", using: :btree
  add_index "case_docket_numbers", ["docket_number"], name: "index_case_docket_numbers_on_docket_number", using: :btree

  create_table "case_jurisdictions", force: true do |t|
    t.string   "abbreviation", limit: 150
    t.string   "name",         limit: 500
    t.text     "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "case_jurisdictions", ["abbreviation"], name: "index_case_jurisdictions_on_abbreviation", using: :btree
  add_index "case_jurisdictions", ["name"], name: "index_case_jurisdictions_on_name", using: :btree

  create_table "case_requests", force: true do |t|
    t.string   "full_name",            limit: 500,                 null: false
    t.date     "decision_date",                                    null: false
    t.string   "author",               limit: 150,                 null: false
    t.integer  "case_jurisdiction_id"
    t.string   "docket_number",        limit: 150,                 null: false
    t.string   "volume",               limit: 150,                 null: false
    t.string   "reporter",             limit: 150,                 null: false
    t.string   "page",                 limit: 150,                 null: false
    t.string   "bluebook_citation",    limit: 150,                 null: false
    t.string   "status",               limit: 150, default: "new", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",                          default: 0,     null: false
  end

  create_table "cases", force: true do |t|
    t.boolean  "current_opinion",                      default: true
    t.string   "short_name",           limit: 150,                     null: false
    t.string   "full_name",            limit: 500
    t.date     "decision_date"
    t.string   "author",               limit: 150
    t.integer  "case_jurisdiction_id"
    t.string   "party_header",         limit: 10240
    t.string   "lawyer_header",        limit: 2048
    t.string   "header_html",          limit: 15360
    t.string   "content",              limit: 5242880,                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                               default: true
    t.boolean  "active",                               default: false
    t.integer  "case_request_id"
    t.integer  "karma"
    t.integer  "pushed_from_id"
    t.boolean  "sent_in_cases_list",                   default: false
    t.integer  "user_id",                              default: 0,     null: false
  end

  add_index "cases", ["active"], name: "index_cases_on_active", using: :btree
  add_index "cases", ["author"], name: "index_cases_on_author", using: :btree
  add_index "cases", ["case_jurisdiction_id"], name: "index_cases_on_case_jurisdiction_id", using: :btree
  add_index "cases", ["created_at"], name: "index_cases_on_created_at", using: :btree
  add_index "cases", ["current_opinion"], name: "index_cases_on_current_opinion", using: :btree
  add_index "cases", ["decision_date"], name: "index_cases_on_decision_date", using: :btree
  add_index "cases", ["full_name"], name: "index_cases_on_full_name", using: :btree
  add_index "cases", ["public"], name: "index_cases_on_public", using: :btree
  add_index "cases", ["short_name"], name: "index_cases_on_short_name", using: :btree
  add_index "cases", ["updated_at"], name: "index_cases_on_updated_at", using: :btree

  create_table "collage_links", force: true do |t|
    t.integer  "host_collage_id",   null: false
    t.integer  "linked_collage_id", null: false
    t.string   "link_text_start",   null: false
    t.string   "link_text_end",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "pushed_from_id"
  end

  create_table "collages", force: true do |t|
    t.string   "annotatable_type"
    t.integer  "annotatable_id"
    t.string   "name",              limit: 250,                    null: false
    t.string   "description",       limit: 5120
    t.string   "content",           limit: 5242880,                null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "word_count"
    t.string   "indexable_content", limit: 5242880
    t.string   "ancestry"
    t.boolean  "public",                            default: true
    t.boolean  "active",                            default: true
    t.string   "readable_state",    limit: 5242880
    t.integer  "words_shown"
    t.integer  "karma"
    t.integer  "pushed_from_id"
    t.integer  "user_id",                           default: 0,    null: false
    t.integer  "annotator_version",                 default: 2,    null: false
  end

  add_index "collages", ["active"], name: "index_collages_on_active", using: :btree
  add_index "collages", ["ancestry"], name: "index_collages_on_ancestry", using: :btree
  add_index "collages", ["annotatable_id"], name: "index_collages_on_annotatable_id", using: :btree
  add_index "collages", ["annotatable_type"], name: "index_collages_on_annotatable_type", using: :btree
  add_index "collages", ["created_at"], name: "index_collages_on_created_at", using: :btree
  add_index "collages", ["name"], name: "index_collages_on_name", using: :btree
  add_index "collages", ["public"], name: "index_collages_on_public", using: :btree
  add_index "collages", ["updated_at"], name: "index_collages_on_updated_at", using: :btree
  add_index "collages", ["word_count"], name: "index_collages_on_word_count", using: :btree

  create_table "collages_user_collections", id: false, force: true do |t|
    t.integer "collage_id"
    t.integer "user_collection_id"
  end

  create_table "color_mappings", force: true do |t|
    t.integer  "collage_id"
    t.integer  "tag_id"
    t.string   "hex"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "defaults", force: true do |t|
    t.string   "name",           limit: 1024
    t.string   "title",          limit: 1024
    t.string   "url",            limit: 1024,                   null: false
    t.string   "description",    limit: 5242880
    t.boolean  "active",                         default: true
    t.boolean  "public",                         default: true
    t.integer  "karma"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "pushed_from_id"
    t.string   "content_type"
    t.integer  "user_id",                        default: 0,    null: false
    t.string   "ancestry"
  end

  create_table "defects", force: true do |t|
    t.text     "description",     null: false
    t.integer  "reportable_id",   null: false
    t.string   "reportable_type", null: false
    t.integer  "user_id",         null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", force: true do |t|
    t.integer  "priority",   default: 0
    t.integer  "attempts",   default: 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "queue"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "imports", force: true do |t|
    t.integer  "bulk_upload_id"
    t.integer  "actual_object_id"
    t.string   "actual_object_type"
    t.string   "dropbox_filepath"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
  end

  create_table "institutions", force: true do |t|
    t.string   "name",       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "institutions_users", id: false, force: true do |t|
    t.integer "institution_id", null: false
    t.integer "user_id",        null: false
  end

  create_table "journal_article_types", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "journal_article_types_journal_articles", id: false, force: true do |t|
    t.integer "journal_article_id"
    t.integer "journal_article_type_id"
  end

  create_table "journal_articles", force: true do |t|
    t.string   "name",                                                      null: false
    t.string   "description",                limit: 5242880,                null: false
    t.date     "publish_date",                                              null: false
    t.string   "subtitle"
    t.string   "author",                                                    null: false
    t.string   "author_description",         limit: 5242880
    t.string   "volume",                                                    null: false
    t.string   "issue",                                                     null: false
    t.string   "page",                                                      null: false
    t.string   "bluebook_citation",                                         null: false
    t.string   "article_series_title"
    t.string   "article_series_description", limit: 5242880
    t.string   "pdf_url"
    t.string   "image"
    t.string   "attribution",                                               null: false
    t.string   "attribution_url"
    t.string   "video_embed",                limit: 5242880
    t.boolean  "active",                                     default: true
    t.boolean  "public",                                     default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",                                    default: 0,    null: false
  end

  create_table "locations", force: true do |t|
    t.string   "name",       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "media_types", force: true do |t|
    t.string   "label"
    t.string   "slug"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "medias", force: true do |t|
    t.string   "name"
    t.text     "content"
    t.integer  "media_type_id"
    t.boolean  "public",                         default: true
    t.boolean  "active",                         default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "description",    limit: 5242880
    t.integer  "karma"
    t.integer  "pushed_from_id"
    t.integer  "user_id",                        default: 0,    null: false
  end

  create_table "metadata", force: true do |t|
    t.string   "contributor"
    t.string   "coverage"
    t.string   "creator"
    t.date     "date"
    t.string   "description",       limit: 5242880
    t.string   "format"
    t.string   "identifier"
    t.string   "language",                          default: "en"
    t.string   "publisher"
    t.string   "relation"
    t.string   "rights"
    t.string   "source"
    t.string   "subject"
    t.string   "title"
    t.string   "dc_type",                           default: "Text"
    t.string   "classifiable_type"
    t.integer  "classifiable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "metadata", ["classifiable_id"], name: "index_metadata_on_classifiable_id", using: :btree
  add_index "metadata", ["classifiable_type"], name: "index_metadata_on_classifiable_type", using: :btree

  create_table "permission_assignments", force: true do |t|
    t.integer  "user_collection_id"
    t.integer  "user_id"
    t.integer  "permission_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "permissions", force: true do |t|
    t.string   "key"
    t.string   "label"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "permission_type"
  end

  create_table "playlist_items", force: true do |t|
    t.integer  "playlist_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "notes"
    t.boolean  "public_notes",                    default: true, null: false
    t.integer  "pushed_from_id"
    t.string   "name",               limit: 1024
    t.string   "url",                limit: 1024
    t.text     "description"
    t.string   "actual_object_type"
    t.integer  "actual_object_id"
  end

  add_index "playlist_items", ["position"], name: "index_playlist_items_on_position", using: :btree

  create_table "playlists", force: true do |t|
    t.string   "name",           limit: 1024
    t.text     "description"
    t.boolean  "active",                      default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                      default: true
    t.string   "ancestry"
    t.integer  "position"
    t.integer  "counter_start",               default: 1,    null: false
    t.integer  "karma"
    t.integer  "pushed_from_id"
    t.integer  "location_id"
    t.string   "when_taught"
    t.integer  "user_id",                     default: 0,    null: false
  end

  add_index "playlists", ["active"], name: "index_playlists_on_active", using: :btree
  add_index "playlists", ["ancestry"], name: "index_playlists_on_ancestry", using: :btree
  add_index "playlists", ["position"], name: "index_playlists_on_position", using: :btree

  create_table "playlists_user_collections", id: false, force: true do |t|
    t.integer "playlist_id"
    t.integer "user_collection_id"
  end

  create_table "question_instances", force: true do |t|
    t.string   "name",                    limit: 250,                 null: false
    t.integer  "user_id"
    t.integer  "project_id"
    t.string   "password",                limit: 128
    t.integer  "featured_question_count",              default: 2
    t.string   "description",             limit: 2000
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                               default: true
    t.boolean  "active",                               default: true
    t.integer  "pushed_from_id"
  end

  add_index "question_instances", ["active"], name: "index_question_instances_on_active", using: :btree
  add_index "question_instances", ["ancestors_count"], name: "index_question_instances_on_ancestors_count", using: :btree
  add_index "question_instances", ["children_count"], name: "index_question_instances_on_children_count", using: :btree
  add_index "question_instances", ["descendants_count"], name: "index_question_instances_on_descendants_count", using: :btree
  add_index "question_instances", ["hidden"], name: "index_question_instances_on_hidden", using: :btree
  add_index "question_instances", ["name"], name: "index_question_instances_on_name", unique: true, using: :btree
  add_index "question_instances", ["parent_id"], name: "index_question_instances_on_parent_id", using: :btree
  add_index "question_instances", ["position"], name: "index_question_instances_on_position", using: :btree
  add_index "question_instances", ["project_id", "position"], name: "index_question_instances_on_project_id_and_position", unique: true, using: :btree
  add_index "question_instances", ["project_id"], name: "index_question_instances_on_project_id", using: :btree
  add_index "question_instances", ["public"], name: "index_question_instances_on_public", using: :btree
  add_index "question_instances", ["user_id"], name: "index_question_instances_on_user_id", using: :btree

  create_table "questions", force: true do |t|
    t.integer  "question_instance_id"
    t.integer  "user_id"
    t.string   "question",             limit: 10000,                 null: false
    t.boolean  "sticky",                             default: false
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                             default: true
    t.boolean  "active",                             default: true
    t.integer  "pushed_from_id"
  end

  add_index "questions", ["active"], name: "index_questions_on_active", using: :btree
  add_index "questions", ["created_at"], name: "index_questions_on_created_at", using: :btree
  add_index "questions", ["parent_id"], name: "index_questions_on_parent_id", using: :btree
  add_index "questions", ["position"], name: "index_questions_on_position", using: :btree
  add_index "questions", ["public"], name: "index_questions_on_public", using: :btree
  add_index "questions", ["question_instance_id"], name: "index_questions_on_question_instance_id", using: :btree
  add_index "questions", ["sticky"], name: "index_questions_on_sticky", using: :btree
  add_index "questions", ["updated_at"], name: "index_questions_on_updated_at", using: :btree
  add_index "questions", ["user_id"], name: "index_questions_on_user_id", using: :btree

  create_table "roles", force: true do |t|
    t.string   "name",              limit: 40
    t.string   "authorizable_type", limit: 40
    t.integer  "authorizable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "roles", ["authorizable_id"], name: "index_roles_on_authorizable_id", using: :btree
  add_index "roles", ["authorizable_type"], name: "index_roles_on_authorizable_type", using: :btree
  add_index "roles", ["name"], name: "index_roles_on_name", using: :btree

  create_table "roles_users", id: false, force: true do |t|
    t.integer  "user_id"
    t.integer  "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "roles_users", ["role_id"], name: "index_roles_users_on_role_id", using: :btree
  add_index "roles_users", ["user_id"], name: "index_roles_users_on_user_id", using: :btree

  create_table "rotisserie_assignments", force: true do |t|
    t.integer  "user_id"
    t.integer  "rotisserie_discussion_id"
    t.integer  "rotisserie_post_id"
    t.integer  "round"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rotisserie_assignments", ["rotisserie_discussion_id"], name: "index_rotisserie_assignments_on_rotisserie_discussion_id", using: :btree
  add_index "rotisserie_assignments", ["rotisserie_post_id"], name: "index_rotisserie_assignments_on_rotisserie_post_id", using: :btree
  add_index "rotisserie_assignments", ["round"], name: "index_rotisserie_assignments_on_round", using: :btree
  add_index "rotisserie_assignments", ["user_id"], name: "index_rotisserie_assignments_on_user_id", using: :btree

  create_table "rotisserie_discussions", force: true do |t|
    t.integer  "rotisserie_instance_id"
    t.string   "title",                  limit: 250,                null: false
    t.text     "output"
    t.text     "description"
    t.text     "notes"
    t.integer  "round_length",                       default: 2
    t.integer  "final_round",                        default: 2
    t.datetime "start_date"
    t.string   "session_id"
    t.boolean  "active",                             default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                             default: true
    t.integer  "pushed_from_id"
    t.integer  "user_id",                            default: 0,    null: false
  end

  add_index "rotisserie_discussions", ["active"], name: "index_rotisserie_discussions_on_active", using: :btree
  add_index "rotisserie_discussions", ["rotisserie_instance_id"], name: "index_rotisserie_discussions_on_rotisserie_instance_id", using: :btree
  add_index "rotisserie_discussions", ["title"], name: "index_rotisserie_discussions_on_title", using: :btree

  create_table "rotisserie_instances", force: true do |t|
    t.string   "title",       limit: 250,                null: false
    t.text     "output"
    t.text     "description"
    t.text     "notes"
    t.string   "session_id"
    t.boolean  "active",                  default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                  default: true
    t.integer  "user_id",                 default: 0,    null: false
  end

  add_index "rotisserie_instances", ["title"], name: "index_rotisserie_instances_on_title", unique: true, using: :btree

  create_table "rotisserie_posts", force: true do |t|
    t.integer  "rotisserie_discussion_id"
    t.integer  "round"
    t.string   "title",                    limit: 250,                null: false
    t.text     "output"
    t.string   "session_id"
    t.boolean  "active",                               default: true
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.boolean  "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",                               default: true
    t.integer  "user_id",                              default: 0,    null: false
  end

  add_index "rotisserie_posts", ["active"], name: "index_rotisserie_posts_on_active", using: :btree
  add_index "rotisserie_posts", ["parent_id"], name: "index_rotisserie_posts_on_parent_id", using: :btree
  add_index "rotisserie_posts", ["position"], name: "index_rotisserie_posts_on_position", using: :btree
  add_index "rotisserie_posts", ["rotisserie_discussion_id"], name: "index_rotisserie_posts_on_rotisserie_discussion_id", using: :btree
  add_index "rotisserie_posts", ["round"], name: "index_rotisserie_posts_on_round", using: :btree

  create_table "rotisserie_trackers", force: true do |t|
    t.integer  "rotisserie_discussion_id"
    t.integer  "rotisserie_post_id"
    t.integer  "user_id"
    t.string   "notify_description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rotisserie_trackers", ["rotisserie_discussion_id"], name: "index_rotisserie_trackers_on_rotisserie_discussion_id", using: :btree
  add_index "rotisserie_trackers", ["rotisserie_post_id"], name: "index_rotisserie_trackers_on_rotisserie_post_id", using: :btree
  add_index "rotisserie_trackers", ["user_id"], name: "index_rotisserie_trackers_on_user_id", using: :btree

  create_table "sessions", force: true do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", using: :btree
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at", using: :btree

  create_table "taggings", force: true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "taggable_type"
    t.string   "context"
    t.datetime "created_at"
  end

  add_index "taggings", ["context"], name: "index_taggings_on_context", using: :btree
  add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true, using: :btree
  add_index "taggings", ["taggable_id"], name: "index_taggings_on_taggable_id", using: :btree
  add_index "taggings", ["taggable_type"], name: "index_taggings_on_taggable_type", using: :btree
  add_index "taggings", ["tagger_id"], name: "index_taggings_on_tagger_id", using: :btree
  add_index "taggings", ["tagger_type"], name: "index_taggings_on_tagger_type", using: :btree

  create_table "tags", force: true do |t|
    t.string  "name"
    t.integer "taggings_count", default: 0
  end

  add_index "tags", ["name"], name: "index_tags_on_name", using: :btree

  create_table "text_blocks", force: true do |t|
    t.string   "name",                                                  null: false
    t.string   "description",    limit: 5242880,                        null: false
    t.string   "mime_type",      limit: 50,      default: "text/plain"
    t.boolean  "active",                         default: true
    t.boolean  "public",                         default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "karma"
    t.integer  "pushed_from_id"
    t.integer  "user_id",                        default: 0,            null: false
  end

  add_index "text_blocks", ["created_at"], name: "index_text_blocks_on_created_at", using: :btree
  add_index "text_blocks", ["mime_type"], name: "index_text_blocks_on_mime_type", using: :btree
  add_index "text_blocks", ["name"], name: "index_text_blocks_on_name", using: :btree
  add_index "text_blocks", ["updated_at"], name: "index_text_blocks_on_updated_at", using: :btree

  create_table "user_collections", force: true do |t|
    t.integer  "owner_id"
    t.string   "name"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_collections_users", id: false, force: true do |t|
    t.integer "user_id"
    t.integer "user_collection_id"
  end

  create_table "users", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "login"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.string   "persistence_token",                        null: false
    t.integer  "login_count",              default: 0,     null: false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.string   "last_login_ip"
    t.string   "current_login_ip"
    t.string   "oauth_token"
    t.string   "oauth_secret"
    t.string   "email_address"
    t.string   "tz_name"
    t.integer  "bookmark_id"
    t.integer  "karma"
    t.string   "attribution"
    t.string   "perishable_token"
    t.boolean  "default_show_annotations", default: false, null: false
    t.boolean  "tab_open_new_items",       default: false, null: false
    t.string   "default_font_size",        default: "16"
    t.string   "title"
    t.string   "affiliation"
    t.string   "url"
    t.text     "description"
    t.string   "canvas_id"
  end

  add_index "users", ["email_address"], name: "index_users_on_email_address", using: :btree
  add_index "users", ["last_request_at"], name: "index_users_on_last_request_at", using: :btree
  add_index "users", ["login"], name: "index_users_on_login", using: :btree
  add_index "users", ["oauth_token"], name: "index_users_on_oauth_token", using: :btree
  add_index "users", ["persistence_token"], name: "index_users_on_persistence_token", using: :btree
  add_index "users", ["tz_name"], name: "index_users_on_tz_name", using: :btree

  create_table "votes", force: true do |t|
    t.boolean  "vote",          default: false
    t.integer  "voteable_id"
    t.string   "voteable_type"
    t.integer  "voter_id"
    t.string   "voter_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "votes", ["voteable_id", "voteable_type"], name: "fk_voteables", using: :btree
  add_index "votes", ["voter_id", "voter_type", "voteable_id", "voteable_type"], name: "uniq_one_vote_only", unique: true, using: :btree
  add_index "votes", ["voter_id", "voter_type"], name: "fk_voters", using: :btree

end
