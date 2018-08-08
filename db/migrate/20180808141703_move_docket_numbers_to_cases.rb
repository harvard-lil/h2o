class MoveDocketNumbersToCases < ActiveRecord::Migration[5.1]
  def up
    # "this field has max_length 20000 because of that one case where the list of docket numbers covers six pages" - Jack Cushman
    add_column :cases, :docket_number, :string, limit: 20000

    # NOTE - there are ~360 cases with multiple docket numbers in the current DB. Going forward, since we'll be pulling our data from CAPAPI which doesn't split out multiple docket numbers and an standardized delimiter to do so doesn't exist, we're combining them in the H2O DB using a \n newline delimiter. No newlines were found in the docket_numbers prior to this migration.
    Case.update_all("docket_number = (SELECT string_agg(docket_number, E'\n') FROM case_docket_numbers WHERE case_id = cases.id GROUP BY case_id)")

    drop_table :case_docket_numbers
  end

  def down
    create_table "case_docket_numbers", id: :serial, force: :cascade do |t|
      t.integer "case_id"
      t.string "docket_number", limit: 200, null: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["case_id"], name: "index_case_docket_numbers_on_case_id"
      t.index ["docket_number"], name: "index_case_docket_numbers_on_docket_number"
    end

    ActiveRecord::Base.connection.execute("INSERT INTO case_docket_numbers (case_id, docket_number, created_at, updated_at) SELECT id, num, current_timestamp, current_timestamp FROM (SELECT id, regexp_split_to_table(docket_number, E'\n') as num FROM cases ORDER BY id) tmp;")

    remove_column :cases, :docket_number
  end
end
