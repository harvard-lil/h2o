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

ActiveRecord::Schema.define(:version => 20100409155520) do

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

  create_table "question_instances", :force => true do |t|
    t.string   "name",                    :limit => 250,                   :null => false
    t.integer  "user_id"
    t.integer  "project_id"
    t.string   "password",                :limit => 128
    t.integer  "featured_question_count",                 :default => 2
    t.integer  "new_question_timeout",                    :default => 30
    t.integer  "old_question_timeout",                    :default => 900
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

  add_index "question_instances", ["name"], :name => "index_question_instances_on_name", :unique => true
  add_index "question_instances", ["new_question_timeout"], :name => "index_question_instances_on_new_question_timeout"
  add_index "question_instances", ["old_question_timeout"], :name => "index_question_instances_on_old_question_timeout"
  add_index "question_instances", ["parent_id"], :name => "index_question_instances_on_parent_id"
  add_index "question_instances", ["position"], :name => "index_question_instances_on_position"
  add_index "question_instances", ["project_id", "position"], :name => "index_question_instances_on_project_id_and_position", :unique => true
  add_index "question_instances", ["project_id"], :name => "index_question_instances_on_project_id"
  add_index "question_instances", ["user_id"], :name => "index_question_instances_on_user_id"

  create_table "questions", :force => true do |t|
    t.integer  "question_instance_id",                                     :null => false
    t.integer  "user_id"
    t.string   "question",             :limit => 10000,                    :null => false
    t.boolean  "posted_anonymously",                    :default => false
    t.string   "email",                :limit => 250
    t.string   "name",                 :limit => 250
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

  add_index "questions", ["email"], :name => "index_questions_on_email"
  add_index "questions", ["parent_id"], :name => "index_questions_on_parent_id"
  add_index "questions", ["position"], :name => "index_questions_on_position"
  add_index "questions", ["question_instance_id"], :name => "index_questions_on_question_instance_id"
  add_index "questions", ["sticky"], :name => "index_questions_on_sticky"
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
