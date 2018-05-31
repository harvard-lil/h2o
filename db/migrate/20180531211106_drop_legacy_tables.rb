class DropLegacyTables < ActiveRecord::Migration[5.1]
  def up
    drop_table :brain_busters
    drop_table :case_ingestion_logs
    drop_table :case_ingestion_requests
    drop_table :case_requests
    drop_table :collages_user_collections
    drop_table :color_mappings
    drop_table :deleted_items
    drop_table :imports
    drop_table :journal_article_types
    drop_table :journal_article_types_journal_articles
    drop_table :journal_articles
    drop_table :locations
    drop_table :question_instances
    drop_table :questions
    drop_table :responses
    drop_table :rotisserie_assignments
    drop_table :rotisserie_discussions
    drop_table :rotisserie_instances
    drop_table :rotisserie_posts
    drop_table :rotisserie_trackers
    drop_table :taggings
    drop_table :tags
  end

  def down
    create_table "brain_busters" do |t|
      t.column :question, :string
      t.column :answer, :string
    end

    create_table "case_ingestion_logs" do |t|
      t.integer "case_ingestion_request_id"
      t.string "status", limit: 255
      t.text "content"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "case_ingestion_requests" do |t|
      t.string "url", limit: 255, null: false
      t.integer "user_id", null: false
      t.integer "case_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "case_requests" do |t|
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

    create_table "collages_user_collections" do |t|
      t.integer "collage_id"
      t.integer "user_collection_id"
    end

    create_table "color_mappings" do |t|
      t.integer "collage_id"
      t.integer "tag_id"
      t.string "hex", limit: 255
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "deleted_items" do |t|
      t.integer "item_id"
      t.string "item_type", limit: 255
      t.datetime "deleted_at"
    end

    create_table "imports" do |t|
      t.integer "bulk_upload_id"
      t.integer "actual_object_id"
      t.string "actual_object_type", limit: 255
      t.string "dropbox_filepath", limit: 255
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "status", limit: 255
    end

    create_table "journal_article_types", id: :serial, force: :cascade do |t|
      t.string "name", limit: 255
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "journal_article_types_journal_articles" do |t|
      t.integer "journal_article_id"
      t.integer "journal_article_type_id"
    end

    create_table "journal_articles" do |t|
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

    create_table "locations" do |t|
      t.string "name", limit: 255, null: false
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "question_instances" do |t|
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

    create_table "questions" do |t|
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

    create_table "responses" do |t|
      t.text "content"
      t.integer "user_id", null: false
      t.string "resource_type", limit: 255, null: false
      t.integer "resource_id", null: false
      t.datetime "created_at"
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

    create_table "rotisserie_discussions" do |t|
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

    create_table "rotisserie_instances" do |t|
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

    create_table "rotisserie_posts" do |t|
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

    create_table "rotisserie_trackers" do |t|
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

    create_table "taggings" do |t|
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

    create_table "tags" do |t|
      t.string "name", limit: 255
      t.integer "taggings_count", default: 0
      t.index ["name"], name: "index_tags_on_name"
    end
  end
end
