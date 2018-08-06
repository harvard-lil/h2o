class ConvertCaseCitationsToAjsonColumnOnCases < ActiveRecord::Migration[5.1]
  def up
    add_column :cases, :citations, :jsonb
    Case.update_all("citations = (SELECT json_agg(json_strip_nulls(json_build_object('volume', volume, 'reporter', reporter, 'page', page, 'type', type))) FROM case_citations WHERE case_id = cases.id)")
    drop_table :case_citations
  end

  def down
    create_table "case_citations", id: :serial, force: :cascade do |t|
      t.integer "case_id"
      t.string "volume", limit: 200, null: false
      t.string "reporter", limit: 200, null: false
      t.string "page", limit: 200, null: false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string "type", limit: 150
      t.index ["case_id"], name: "index_case_citations_on_case_id"
      t.index ["page"], name: "index_case_citations_on_page"
      t.index ["reporter"], name: "index_case_citations_on_reporter"
      t.index ["volume"], name: "index_case_citations_on_volume"
    end
    CaseCitation.connection.execute("INSERT INTO case_citations (case_id, volume, reporter, page, created_at, updated_at) SELECT id, data::json->>'volume', data::json->>'reporter', data::json->>'page', current_timestamp, current_timestamp FROM (SELECT id, jsonb_array_elements(citations) as data FROM cases ORDER BY id) tmp;")

    remove_column :cases, :citations
  end
end
