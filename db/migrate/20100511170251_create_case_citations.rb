require 'migration_helpers'
class CreateCaseCitations < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :case_citations do |t|
      t.references :case
      t.string :volume,     :limit => 200,  :null => false
      t.string :reporter,   :limit => 200,  :null => false
      t.string :page,       :limit => 200,  :null => false
      t.timestamps
    end
    [:case_id,:volume,:reporter,:page].each do |col|
      add_index :case_citations, col
    end
    create_foreign_key(CaseCitation,Case)
  end

  def self.down
    drop_table :case_citations
  end
end
