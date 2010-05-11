class CreateCaseJurisdictions < ActiveRecord::Migration
  def self.up
    create_table :case_jurisdictions do |t|
      t.string :abbreviation,   :limit => 150
      t.string :name,           :limit => 500
      t.text :content
      t.timestamps
    end

    [:abbreviation, :name].each do |col|
      add_index :case_jurisdictions, col
    end

  end

  def self.down
    drop_table :case_jurisdictions
  end
end
