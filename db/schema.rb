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

ActiveRecord::Schema.define(version: 2019_06_05_125852) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "plpgsql"

  create_table "annotations", id: :serial, force: :cascade do |t|
    t.integer "collage_id"
    t.string "annotation", limit: 10240
    t.datetime "created_at"
    t.datetime "updated_at"
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

  create_table "case_courts", id: :serial, force: :cascade do |t|
    t.string "name_abbreviation", limit: 150
    t.string "name", limit: 500
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "capapi_id"
    t.index ["name"], name: "index_case_courts_on_name"
    t.index ["name_abbreviation"], name: "index_case_courts_on_name_abbreviation"
  end

  create_table "cases", id: :serial, force: :cascade do |t|
    t.string "name_abbreviation", limit: 150, null: false
    t.string "name"
    t.date "decision_date"
    t.integer "case_court_id"
    t.string "header_html", limit: 15360
    t.string "content", limit: 5242880, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "public", default: false
    t.boolean "created_via_import", default: false, null: false
    t.integer "capapi_id"
    t.jsonb "attorneys"
    t.jsonb "parties"
    t.jsonb "opinions"
    t.jsonb "citations"
    t.string "docket_number", limit: 20000
    t.integer "annotations_count", default: 0
    t.index ["case_court_id"], name: "index_cases_on_case_court_id"
    t.index ["citations"], name: "index_cases_on_citations", using: :gin
    t.index ["created_at"], name: "index_cases_on_created_at"
    t.index ["decision_date"], name: "index_cases_on_decision_date"
    t.index ["name_abbreviation"], name: "index_cases_on_name_abbreviation"
    t.index ["public"], name: "index_cases_on_public"
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

  create_table "content_annotations", force: :cascade do |t|
    t.bigint "resource_id", null: false
    t.integer "start_paragraph", null: false
    t.integer "end_paragraph"
    t.integer "start_offset", null: false
    t.integer "end_offset", null: false
    t.string "kind", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "global_start_offset"
    t.integer "global_end_offset"
    t.index ["resource_id", "start_paragraph"], name: "index_content_annotations_on_resource_id_and_start_paragraph"
    t.index ["resource_id"], name: "index_content_annotations_on_resource_id"
  end

  create_table "content_collaborators", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "content_id"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_attribution", default: false, null: false
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
    t.text "raw_headnote"
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
    t.boolean "draft_mode_of_published_casebook"
    t.boolean "cloneable", default: true, null: false
    t.text "headnote"
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
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "content_type", limit: 255
    t.integer "user_id", default: 0
    t.string "ancestry", limit: 255
    t.boolean "created_via_import", default: false, null: false
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

  create_table "frozen_items", id: :serial, force: :cascade do |t|
    t.text "content"
    t.integer "version", null: false
    t.integer "item_id", null: false
    t.string "item_type", limit: 255, null: false
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

  create_table "raw_contents", force: :cascade do |t|
    t.text "content"
    t.string "source_type"
    t.bigint "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id"], name: "index_raw_contents_on_source_type_and_source_id", unique: true
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
    t.integer "user_id", default: 0
    t.boolean "created_via_import", default: false, null: false
    t.string "description", limit: 5242880
    t.integer "version", default: 1, null: false
    t.boolean "enable_feedback", default: true, null: false
    t.boolean "enable_discussions", default: false, null: false
    t.boolean "enable_responses", default: false, null: false
    t.integer "annotations_count", default: 0
    t.index ["created_at"], name: "index_text_blocks_on_created_at"
    t.index ["name"], name: "index_text_blocks_on_name"
    t.index ["updated_at"], name: "index_text_blocks_on_updated_at"
  end

  create_table "unpublished_revisions", force: :cascade do |t|
    t.integer "node_id"
    t.string "field", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "casebook_id"
    t.integer "node_parent_id"
    t.integer "annotation_id"
    t.index ["node_id", "field"], name: "index_unpublished_revisions_on_node_id_and_field"
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
    t.string "attribution", limit: 255, default: "Anonymous", null: false
    t.string "perishable_token", limit: 255
    t.string "default_font_size", limit: 255, default: "10"
    t.string "title", limit: 255
    t.string "affiliation", limit: 255
    t.string "url", limit: 255
    t.text "description"
    t.string "canvas_id", limit: 255
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
    t.boolean "verified_professor", default: false
    t.boolean "professor_verification_requested", default: false
    t.boolean "verified_email", default: false, null: false
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

  add_foreign_key "content_annotations", "content_nodes", column: "resource_id", on_delete: :cascade
  add_foreign_key "content_collaborators", "content_nodes", column: "content_id"
  add_foreign_key "content_nodes", "content_nodes", column: "casebook_id", on_delete: :cascade
  add_foreign_key "content_nodes", "content_nodes", column: "copy_of_id", on_delete: :nullify
end
