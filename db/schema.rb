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

ActiveRecord::Schema.define(version: 20171114212553) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "btree_gin"

  create_table "annotations", id: :serial, force: :cascade do |t|
    t.integer "collage_id"
    t.string "annotation", limit: 10240
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "pushed_from_id"
    t.boolean "cloned", default: false, null: false
    t.string "xpath_start", limit: 255
    t.string "xpath_end", limit: 255
    t.integer "start_offset", default: 0, null: false
    t.integer "end_offset", default: 0, null: false
    t.string "link", limit: 255
    t.boolean "hidden", default: false, null: false
    t.string "highlight_only", limit: 255
    t.integer "annotated_item_id", default: 0, null: false
    t.string "annotated_item_type", limit: 255, default: "Collage", null: false
    t.boolean "error", default: false, null: false
    t.boolean "feedback", default: false, null: false
    t.boolean "discussion", default: false, null: false
    t.integer "user_id"
  end

  create_table "brain_busters", id: :serial, force: :cascade do |t|
    t.string "question", limit: 255
    t.string "answer", limit: 255
  end

  create_table "bulk_uploads", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "has_errors"
    t.integer "delayed_job_id"
    t.integer "user_id", default: 0, null: false
  end

  create_table "case_citations", id: :serial, force: :cascade do |t|
    t.integer "case_id"
    t.string "volume", limit: 200, null: false
    t.string "reporter", limit: 200, null: false
    t.string "page", limit: 200, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["case_id"], name: "index_case_citations_on_case_id"
    t.index ["page"], name: "index_case_citations_on_page"
    t.index ["reporter"], name: "index_case_citations_on_reporter"
    t.index ["volume"], name: "index_case_citations_on_volume"
  end

  create_table "case_docket_numbers", id: :serial, force: :cascade do |t|
    t.integer "case_id"
    t.string "docket_number", limit: 200, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["case_id"], name: "index_case_docket_numbers_on_case_id"
    t.index ["docket_number"], name: "index_case_docket_numbers_on_docket_number"
  end

  create_table "case_ingestion_logs", id: :serial, force: :cascade do |t|
    t.integer "case_ingestion_request_id"
    t.string "status", limit: 255
    t.text "content"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "case_ingestion_requests", id: :serial, force: :cascade do |t|
    t.string "url", limit: 255, null: false
    t.integer "user_id", null: false
    t.integer "case_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "case_jurisdictions", id: :serial, force: :cascade do |t|
    t.string "abbreviation", limit: 150
    t.string "name", limit: 500
    t.text "content"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["abbreviation"], name: "index_case_jurisdictions_on_abbreviation"
    t.index ["name"], name: "index_case_jurisdictions_on_name"
  end

  create_table "case_requests", id: :serial, force: :cascade do |t|
    t.string "full_name", limit: 500, null: false
    t.date "decision_date", null: false
    t.string "author", limit: 150, null: false
    t.integer "case_jurisdiction_id"
    t.string "docket_number", limit: 150, null: false
    t.string "volume", limit: 150, null: false
    t.string "reporter", limit: 150, null: false
    t.string "page", limit: 150, null: false
    t.string "bluebook_citation", limit: 150, null: false
    t.string "status", limit: 150, default: "new", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id", default: 0, null: false
  end

  create_table "cases", id: :serial, force: :cascade do |t|
    t.boolean "current_opinion", default: true
    t.string "short_name", limit: 150, null: false
    t.string "full_name"
    t.date "decision_date"
    t.string "author", limit: 150
    t.integer "case_jurisdiction_id"
    t.string "party_header", limit: 10240
    t.string "lawyer_header", limit: 2048
    t.string "header_html", limit: 15360
    t.string "content", limit: 5242880, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: false
    t.integer "case_request_id"
    t.integer "karma"
    t.integer "pushed_from_id"
    t.boolean "sent_in_cases_list", default: false
    t.integer "user_id", default: 0
    t.boolean "created_via_import", default: false, null: false
    t.index ["author"], name: "index_cases_on_author"
    t.index ["case_jurisdiction_id"], name: "index_cases_on_case_jurisdiction_id"
    t.index ["created_at"], name: "index_cases_on_created_at"
    t.index ["current_opinion"], name: "index_cases_on_current_opinion"
    t.index ["decision_date"], name: "index_cases_on_decision_date"
    t.index ["public"], name: "index_cases_on_public"
    t.index ["short_name"], name: "index_cases_on_short_name"
    t.index ["updated_at"], name: "index_cases_on_updated_at"
  end

  create_table "ckeditor_assets", id: :serial, force: :cascade do |t|
    t.string "data_file_name", limit: 255, null: false
    t.string "data_content_type", limit: 255
    t.integer "data_file_size"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type"
  end

  create_table "collages", id: :serial, force: :cascade do |t|
    t.string "annotatable_type", limit: 255
    t.integer "annotatable_id"
    t.string "name", limit: 250, null: false
    t.string "description", limit: 5120
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "word_count"
    t.string "ancestry", limit: 255
    t.boolean "public", default: true
    t.string "readable_state", limit: 5242880
    t.integer "words_shown"
    t.integer "karma"
    t.integer "pushed_from_id"
    t.integer "user_id", default: 0, null: false
    t.integer "annotator_version", default: 2, null: false
    t.boolean "featured", default: false, null: false
    t.boolean "created_via_import", default: false, null: false
    t.integer "version", default: 1, null: false
    t.boolean "enable_feedback", default: true, null: false
    t.boolean "enable_discussions", default: false, null: false
    t.boolean "enable_responses", default: false, null: false
    t.index ["ancestry"], name: "index_collages_on_ancestry"
    t.index ["annotatable_id"], name: "index_collages_on_annotatable_id"
    t.index ["annotatable_type"], name: "index_collages_on_annotatable_type"
    t.index ["created_at"], name: "index_collages_on_created_at"
    t.index ["name"], name: "index_collages_on_name"
    t.index ["public"], name: "index_collages_on_public"
    t.index ["updated_at"], name: "index_collages_on_updated_at"
    t.index ["word_count"], name: "index_collages_on_word_count"
  end

  create_table "collages_user_collections", id: false, force: :cascade do |t|
    t.integer "collage_id"
    t.integer "user_collection_id"
  end

  create_table "color_mappings", id: :serial, force: :cascade do |t|
    t.integer "collage_id"
    t.integer "tag_id"
    t.string "hex", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "content_annotations", force: :cascade do |t|
    t.bigint "resource_id", null: false
    t.integer "start_p", null: false
    t.integer "end_p"
    t.integer "start_offset", null: false
    t.integer "end_offset", null: false
    t.string "kind", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_id", "start_p"], name: "index_content_annotations_on_resource_id_and_start_p"
    t.index ["resource_id"], name: "index_content_annotations_on_resource_id"
  end

  create_table "content_collaborators", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "content_id"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_id"], name: "index_content_collaborators_on_content_id"
    t.index ["user_id", "content_id"], name: "index_content_collaborators_on_user_id_and_content_id", unique: true
    t.index ["user_id"], name: "index_content_collaborators_on_user_id"
  end

  create_table "content_images", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "page_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "image_file_name", limit: 255
    t.string "image_content_type", limit: 255
    t.integer "image_file_size"
    t.datetime "image_updated_at"
  end

  create_table "content_nodes", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.string "subtitle"
    t.text "headnote"
    t.boolean "public", default: true, null: false
    t.bigint "casebook_id"
    t.integer "ordinals", default: [], null: false, array: true
    t.bigint "copy_of_id"
    t.boolean "is_alias"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ancestry"
    t.bigint "playlist_id"
    t.bigint "root_user_id"
    t.index ["ancestry"], name: "index_content_nodes_on_ancestry"
    t.index ["casebook_id", "ordinals"], name: "index_content_nodes_on_casebook_id_and_ordinals", using: :gin
    t.index ["casebook_id"], name: "index_content_nodes_on_casebook_id"
    t.index ["copy_of_id"], name: "index_content_nodes_on_copy_of_id"
    t.index ["resource_type", "resource_id"], name: "index_content_nodes_on_resource_type_and_resource_id"
  end

  create_table "defaults", id: :serial, force: :cascade do |t|
    t.string "name", limit: 1024
    t.string "url", limit: 1024, null: false
    t.string "description", limit: 5242880
    t.boolean "public", default: true
    t.integer "karma"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "pushed_from_id"
    t.string "content_type", limit: 255
    t.integer "user_id", default: 0
    t.string "ancestry", limit: 255
    t.boolean "created_via_import", default: false, null: false
  end

  create_table "defects", id: :serial, force: :cascade do |t|
    t.text "description", null: false
    t.integer "reportable_id", null: false
    t.string "reportable_type", limit: 255, null: false
    t.integer "user_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "queue", limit: 255
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "deleted_items", id: :serial, force: :cascade do |t|
    t.integer "item_id"
    t.string "item_type", limit: 255
    t.datetime "deleted_at"
  end

  create_table "frozen_items", id: :serial, force: :cascade do |t|
    t.text "content"
    t.integer "version", null: false
    t.integer "item_id", null: false
    t.string "item_type", limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "imports", id: :serial, force: :cascade do |t|
    t.integer "bulk_upload_id"
    t.integer "actual_object_id"
    t.string "actual_object_type", limit: 255
    t.string "dropbox_filepath", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "status", limit: 255
  end

  create_table "institutions", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "institutions_users", id: false, force: :cascade do |t|
    t.integer "institution_id", null: false
    t.integer "user_id", null: false
  end

  create_table "journal_article_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "journal_article_types_journal_articles", id: false, force: :cascade do |t|
    t.integer "journal_article_id"
    t.integer "journal_article_type_id"
  end

  create_table "journal_articles", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "description", limit: 5242880, null: false
    t.date "publish_date", null: false
    t.string "subtitle", limit: 255
    t.string "author", limit: 255, null: false
    t.string "author_description", limit: 5242880
    t.string "volume", limit: 255, null: false
    t.string "issue", limit: 255, null: false
    t.string "page", limit: 255, null: false
    t.string "bluebook_citation", limit: 255, null: false
    t.string "article_series_title", limit: 255
    t.string "article_series_description", limit: 5242880
    t.string "pdf_url", limit: 255
    t.string "image", limit: 255
    t.string "attribution", limit: 255, null: false
    t.string "attribution_url", limit: 255
    t.string "video_embed", limit: 5242880
    t.boolean "active", default: true
    t.boolean "public", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id", default: 0, null: false
  end

  create_table "locations", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "media_types", id: :serial, force: :cascade do |t|
    t.string "label", limit: 255
    t.string "slug", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "medias", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.text "content"
    t.integer "media_type_id"
    t.boolean "public", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "description", limit: 5242880
    t.integer "karma"
    t.integer "pushed_from_id"
    t.integer "user_id", default: 0, null: false
    t.boolean "created_via_import", default: false, null: false
  end

  create_table "metadata", id: :serial, force: :cascade do |t|
    t.string "contributor", limit: 255
    t.string "coverage", limit: 255
    t.string "creator", limit: 255
    t.date "date"
    t.string "description", limit: 5242880
    t.string "format", limit: 255
    t.string "identifier", limit: 255
    t.string "language", limit: 255, default: "en"
    t.string "publisher", limit: 255
    t.string "relation", limit: 255
    t.string "rights", limit: 255
    t.string "source", limit: 255
    t.string "subject", limit: 255
    t.string "title", limit: 255
    t.string "dc_type", limit: 255, default: "Text"
    t.string "classifiable_type", limit: 255
    t.integer "classifiable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["classifiable_id"], name: "index_metadata_on_classifiable_id"
    t.index ["classifiable_type"], name: "index_metadata_on_classifiable_type"
  end

  create_table "pages", id: :serial, force: :cascade do |t|
    t.string "page_title", limit: 255, null: false
    t.string "slug", limit: 255, null: false
    t.text "content"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "footer_link", default: false, null: false
    t.string "footer_link_text", limit: 255
    t.integer "footer_sort", default: 1000, null: false
    t.boolean "is_user_guide", default: false, null: false
    t.integer "user_guide_sort", default: 1000, null: false
    t.string "user_guide_link_text", limit: 255
  end

  create_table "permission_assignments", id: :serial, force: :cascade do |t|
    t.integer "user_collection_id"
    t.integer "user_id"
    t.integer "permission_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "permissions", id: :serial, force: :cascade do |t|
    t.string "key", limit: 255
    t.string "label", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "permission_type", limit: 255
  end

  create_table "playlist_items", id: :serial, force: :cascade do |t|
    t.integer "playlist_id"
    t.integer "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "notes"
    t.boolean "public_notes", default: true, null: false
    t.integer "pushed_from_id"
    t.string "actual_object_type", limit: 255
    t.integer "actual_object_id"
    t.index ["position"], name: "index_playlist_items_on_position"
  end

  create_table "playlists", id: :serial, force: :cascade do |t|
    t.string "name", limit: 1024
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: true
    t.string "ancestry", limit: 255
    t.integer "position"
    t.integer "counter_start", default: 1, null: false
    t.integer "karma"
    t.integer "pushed_from_id"
    t.integer "location_id"
    t.string "when_taught", limit: 255
    t.integer "user_id", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.boolean "featured", default: false, null: false
    t.boolean "created_via_import", default: false, null: false
    t.index ["ancestry"], name: "index_playlists_on_ancestry"
    t.index ["position"], name: "index_playlists_on_position"
  end

  create_table "playlists_user_collections", id: false, force: :cascade do |t|
    t.integer "playlist_id"
    t.integer "user_collection_id"
  end

  create_table "question_instances", id: :serial, force: :cascade do |t|
    t.string "name", limit: 250, null: false
    t.integer "user_id"
    t.integer "project_id"
    t.string "password", limit: 128
    t.integer "featured_question_count", default: 2
    t.string "description", limit: 2000
    t.integer "parent_id"
    t.integer "children_count"
    t.integer "ancestors_count"
    t.integer "descendants_count"
    t.integer "position"
    t.boolean "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: true
    t.boolean "active", default: true
    t.integer "pushed_from_id"
    t.index ["active"], name: "index_question_instances_on_active"
    t.index ["ancestors_count"], name: "index_question_instances_on_ancestors_count"
    t.index ["children_count"], name: "index_question_instances_on_children_count"
    t.index ["descendants_count"], name: "index_question_instances_on_descendants_count"
    t.index ["hidden"], name: "index_question_instances_on_hidden"
    t.index ["name"], name: "index_question_instances_on_name", unique: true
    t.index ["parent_id"], name: "index_question_instances_on_parent_id"
    t.index ["position"], name: "index_question_instances_on_position"
    t.index ["project_id", "position"], name: "index_question_instances_on_project_id_and_position", unique: true
    t.index ["project_id"], name: "index_question_instances_on_project_id"
    t.index ["public"], name: "index_question_instances_on_public"
    t.index ["user_id"], name: "index_question_instances_on_user_id"
  end

  create_table "questions", id: :serial, force: :cascade do |t|
    t.integer "question_instance_id"
    t.integer "user_id"
    t.string "question", limit: 10000, null: false
    t.boolean "sticky", default: false
    t.integer "parent_id"
    t.integer "children_count"
    t.integer "ancestors_count"
    t.integer "descendants_count"
    t.integer "position"
    t.boolean "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: true
    t.boolean "active", default: true
    t.integer "pushed_from_id"
    t.index ["active"], name: "index_questions_on_active"
    t.index ["created_at"], name: "index_questions_on_created_at"
    t.index ["parent_id"], name: "index_questions_on_parent_id"
    t.index ["position"], name: "index_questions_on_position"
    t.index ["public"], name: "index_questions_on_public"
    t.index ["question_instance_id"], name: "index_questions_on_question_instance_id"
    t.index ["sticky"], name: "index_questions_on_sticky"
    t.index ["updated_at"], name: "index_questions_on_updated_at"
    t.index ["user_id"], name: "index_questions_on_user_id"
  end

  create_table "responses", id: :serial, force: :cascade do |t|
    t.text "content"
    t.integer "user_id", null: false
    t.string "resource_type", limit: 255, null: false
    t.integer "resource_id", null: false
    t.datetime "created_at"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name", limit: 40
    t.string "authorizable_type", limit: 40
    t.integer "authorizable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["authorizable_id"], name: "index_roles_on_authorizable_id"
    t.index ["authorizable_type"], name: "index_roles_on_authorizable_type"
    t.index ["name"], name: "index_roles_on_name"
  end

  create_table "roles_users", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["role_id"], name: "index_roles_users_on_role_id"
    t.index ["user_id"], name: "index_roles_users_on_user_id"
  end

  create_table "rotisserie_assignments", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "rotisserie_discussion_id"
    t.integer "rotisserie_post_id"
    t.integer "round"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["rotisserie_discussion_id"], name: "index_rotisserie_assignments_on_rotisserie_discussion_id"
    t.index ["rotisserie_post_id"], name: "index_rotisserie_assignments_on_rotisserie_post_id"
    t.index ["round"], name: "index_rotisserie_assignments_on_round"
    t.index ["user_id"], name: "index_rotisserie_assignments_on_user_id"
  end

  create_table "rotisserie_discussions", id: :serial, force: :cascade do |t|
    t.integer "rotisserie_instance_id"
    t.string "title", limit: 250, null: false
    t.text "output"
    t.text "description"
    t.text "notes"
    t.integer "round_length", default: 2
    t.integer "final_round", default: 2
    t.datetime "start_date"
    t.string "session_id", limit: 255
    t.boolean "active", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: true
    t.integer "pushed_from_id"
    t.integer "user_id", default: 0, null: false
    t.index ["active"], name: "index_rotisserie_discussions_on_active"
    t.index ["rotisserie_instance_id"], name: "index_rotisserie_discussions_on_rotisserie_instance_id"
    t.index ["title"], name: "index_rotisserie_discussions_on_title"
  end

  create_table "rotisserie_instances", id: :serial, force: :cascade do |t|
    t.string "title", limit: 250, null: false
    t.text "output"
    t.text "description"
    t.text "notes"
    t.string "session_id", limit: 255
    t.boolean "active", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: true
    t.integer "user_id", default: 0, null: false
    t.index ["title"], name: "index_rotisserie_instances_on_title", unique: true
  end

  create_table "rotisserie_posts", id: :serial, force: :cascade do |t|
    t.integer "rotisserie_discussion_id"
    t.integer "round"
    t.string "title", limit: 250, null: false
    t.text "output"
    t.string "session_id", limit: 255
    t.boolean "active", default: true
    t.integer "parent_id"
    t.integer "children_count"
    t.integer "ancestors_count"
    t.integer "descendants_count"
    t.integer "position"
    t.boolean "hidden"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: true
    t.integer "user_id", default: 0, null: false
    t.index ["active"], name: "index_rotisserie_posts_on_active"
    t.index ["parent_id"], name: "index_rotisserie_posts_on_parent_id"
    t.index ["position"], name: "index_rotisserie_posts_on_position"
    t.index ["rotisserie_discussion_id"], name: "index_rotisserie_posts_on_rotisserie_discussion_id"
    t.index ["round"], name: "index_rotisserie_posts_on_round"
  end

  create_table "rotisserie_trackers", id: :serial, force: :cascade do |t|
    t.integer "rotisserie_discussion_id"
    t.integer "rotisserie_post_id"
    t.integer "user_id"
    t.string "notify_description", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["rotisserie_discussion_id"], name: "index_rotisserie_trackers_on_rotisserie_discussion_id"
    t.index ["rotisserie_post_id"], name: "index_rotisserie_trackers_on_rotisserie_post_id"
    t.index ["user_id"], name: "index_rotisserie_trackers_on_user_id"
  end

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.string "session_id", limit: 255, null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.integer "taggable_id"
    t.integer "tagger_id"
    t.string "tagger_type", limit: 255
    t.string "taggable_type", limit: 255
    t.string "context", limit: 255
    t.datetime "created_at"
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tagger_type"], name: "index_taggings_on_tagger_type"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name"
  end

  create_table "text_blocks", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "content", limit: 5242880, null: false
    t.boolean "public", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "karma"
    t.integer "pushed_from_id"
    t.integer "user_id", default: 0
    t.boolean "created_via_import", default: false, null: false
    t.string "description", limit: 5242880
    t.integer "version", default: 1, null: false
    t.boolean "enable_feedback", default: true, null: false
    t.boolean "enable_discussions", default: false, null: false
    t.boolean "enable_responses", default: false, null: false
    t.index ["created_at"], name: "index_text_blocks_on_created_at"
    t.index ["name"], name: "index_text_blocks_on_name"
    t.index ["updated_at"], name: "index_text_blocks_on_updated_at"
  end

  create_table "user_collections", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "name", limit: 255
    t.string "description", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_collections_users", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "user_collection_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "login", limit: 255
    t.string "crypted_password", limit: 255
    t.string "password_salt", limit: 255
    t.string "persistence_token", limit: 255, null: false
    t.integer "login_count", default: 0, null: false
    t.datetime "last_request_at"
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.string "last_login_ip", limit: 255
    t.string "current_login_ip", limit: 255
    t.string "oauth_token", limit: 255
    t.string "oauth_secret", limit: 255
    t.string "email_address", limit: 255
    t.string "tz_name", limit: 255
    t.integer "bookmark_id"
    t.integer "karma"
    t.string "attribution", limit: 255
    t.string "perishable_token", limit: 255
    t.boolean "tab_open_new_items", default: false, null: false
    t.string "default_font_size", limit: 255, default: "10"
    t.string "title", limit: 255
    t.string "affiliation", limit: 255
    t.string "url", limit: 255
    t.text "description"
    t.string "canvas_id", limit: 255
    t.boolean "verified", default: false, null: false
    t.string "default_font", limit: 255, default: "futura"
    t.boolean "print_titles", default: true, null: false
    t.boolean "print_dates_details", default: true, null: false
    t.boolean "print_paragraph_numbers", default: true, null: false
    t.boolean "print_annotations", default: false, null: false
    t.string "print_highlights", limit: 255, default: "original", null: false
    t.string "print_font_face", limit: 255, default: "dagny", null: false
    t.string "print_font_size", limit: 255, default: "small", null: false
    t.boolean "default_show_comments", default: false, null: false
    t.boolean "default_show_paragraph_numbers", default: true, null: false
    t.boolean "hidden_text_display", default: false, null: false
    t.boolean "print_links", default: true, null: false
    t.string "toc_levels", limit: 255, default: "", null: false
    t.string "print_export_format", limit: 255, default: "", null: false
    t.string "image_file_name"
    t.string "image_content_type"
    t.integer "image_file_size"
    t.datetime "image_updated_at"
    t.index ["affiliation"], name: "index_users_on_affiliation"
    t.index ["attribution"], name: "index_users_on_attribution"
    t.index ["email_address"], name: "index_users_on_email_address"
    t.index ["id"], name: "index_users_on_id"
    t.index ["last_request_at"], name: "index_users_on_last_request_at"
    t.index ["login"], name: "index_users_on_login"
    t.index ["oauth_token"], name: "index_users_on_oauth_token"
    t.index ["persistence_token"], name: "index_users_on_persistence_token"
    t.index ["tz_name"], name: "index_users_on_tz_name"
  end

  create_table "votes", id: :serial, force: :cascade do |t|
    t.boolean "vote", default: false
    t.integer "voteable_id"
    t.string "voteable_type", limit: 255
    t.integer "voter_id"
    t.string "voter_type", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["voteable_id", "voteable_type"], name: "fk_voteables"
    t.index ["voter_id", "voter_type", "voteable_id", "voteable_type"], name: "uniq_one_vote_only", unique: true
    t.index ["voter_id", "voter_type"], name: "fk_voters"
  end

  add_foreign_key "content_annotations", "content_nodes", column: "resource_id", on_delete: :cascade
  add_foreign_key "content_collaborators", "content_nodes", column: "content_id"
  add_foreign_key "content_nodes", "content_nodes", column: "casebook_id", on_delete: :cascade
  add_foreign_key "content_nodes", "content_nodes", column: "copy_of_id", on_delete: :nullify
end
