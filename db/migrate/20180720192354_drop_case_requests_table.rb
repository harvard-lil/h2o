class DropCaseRequestsTable < ActiveRecord::Migration[5.1]
  def change
    remove_column :cases, :case_request_id, :integer

    drop_table :case_requests do |t|
      t.string "name", limit: 500, null: false
      t.date "decision_date", null: false
      t.integer "case_court_id"
      t.string "docket_number", limit: 150, null: false
      t.string "volume", limit: 150, null: false
      t.string "reporter", limit: 150, null: false
      t.string "page", limit: 150, null: false
      t.string "bluebook_citation", limit: 150, null: false
      t.string "status", limit: 150, default: "new", null: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer "user_id", default: 0, null: false
      t.jsonb "opinions"
    end
  end
end
