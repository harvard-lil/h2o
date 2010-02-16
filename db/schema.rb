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

ActiveRecord::Schema.define(:version => 20100202182512) do

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
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "questions", ["email"], :name => "index_questions_on_email"
  add_index "questions", ["parent_id"], :name => "index_questions_on_parent_id"
  add_index "questions", ["position"], :name => "index_questions_on_position"
  add_index "questions", ["question_instance_id", "position"], :name => "unique_in_question_instance", :unique => true
  add_index "questions", ["question_instance_id"], :name => "index_questions_on_question_instance_id"
  add_index "questions", ["user_id", "question_instance_id", "position"], :name => "unique_user_in_question_instance", :unique => true
  add_index "questions", ["user_id"], :name => "index_questions_on_user_id"

  create_table "replies", :force => true do |t|
    t.integer  "question_id",                                           :null => false
    t.integer  "user_id"
    t.string   "reply",              :limit => 1000,                    :null => false
    t.string   "email",              :limit => 250
    t.string   "name",               :limit => 250
    t.boolean  "posted_anonymously",                 :default => false
    t.integer  "parent_id"
    t.integer  "children_count"
    t.integer  "ancestors_count"
    t.integer  "descendants_count"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "replies", ["email"], :name => "index_replies_on_email"
  add_index "replies", ["parent_id"], :name => "index_replies_on_parent_id"
  add_index "replies", ["position"], :name => "index_replies_on_position"
  add_index "replies", ["question_id", "position"], :name => "index_replies_on_question_id_and_position", :unique => true
  add_index "replies", ["question_id"], :name => "index_replies_on_question_id"
  add_index "replies", ["user_id", "question_id", "position"], :name => "index_replies_on_user_id_and_question_id_and_position", :unique => true
  add_index "replies", ["user_id"], :name => "index_replies_on_user_id"

  create_table "roles", :force => true do |t|
    t.string   "name",              :limit => 40
    t.string   "authorizable_type", :limit => 40
    t.integer  "authorizable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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
  end

  add_index "users", ["last_request_at"], :name => "index_users_on_last_request_at"
  add_index "users", ["login"], :name => "index_users_on_login"
  add_index "users", ["oauth_token"], :name => "index_users_on_oauth_token"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"

end
