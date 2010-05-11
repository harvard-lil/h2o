require 'migration_helpers'
class CreateCaseDocketNumbers < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :case_docket_numbers do |t|
      t.references :case
      t.string :docket_number, :limit => 200,   :null => false
      t.timestamps
    end
    [:case_id, :docket_number].each do |col|
      add_index :case_docket_numbers, col
    end
    create_foreign_key(CaseDocketNumber,Case)
  end

  def self.down
    drop_table :case_docket_numbers
  end
end
