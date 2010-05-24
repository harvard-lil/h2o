require 'migration_helpers'
class CreateCases < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :cases do |t|
      t.boolean   :current_opinion,   :default => true
      t.string    :short_name,        :limit => 150,  :null => false
      t.string    :full_name,         :limit => 500,  :null => false
      t.date      :decision_date
      t.string    :author,            :limit => 150
      t.text    :party_header,      :limit => 10.kilobytes
      t.text    :lawyer_header,     :limit => 2.kilobytes
      #Should probably be a little larger than the two fields above as it encompasses them.
      t.text    :header_html,       :limit => 15.kilobytes
      t.references :case_jurisdiction
      t.text    :content,           :limit => 5.megabytes,  :null => false
      t.timestamps
    end

    [:current_opinion,:short_name, :full_name, :decision_date, :author, :case_jurisdiction_id, :updated_at, :created_at].each do |col|
      add_index :cases, col
    end

    create_foreign_key(Case,CaseJurisdiction)

  end

  def self.down
    drop_table :cases
  end
end
