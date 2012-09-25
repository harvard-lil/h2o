class CreateCaseRequests < ActiveRecord::Migration
  def self.up
    create_table :case_requests do |t|
      t.string      :full_name, :limit => 500, :null => false
      t.date        :decision_date, :null => false
      t.string      :author, :limit => 150, :null => false
      t.references  :case_jurisdiction
      t.string      :docket_number, :limit => 150,  :null => false
      t.string      :volume, :limit => 150, :null => false
      t.string      :reporter, :limit => 150, :null => false
      t.string      :page, :limit => 150, :null => false
      t.string      :bluebook_citation, :limit => 150, :null => false
      t.string      :status, :limit => 150, :null => false, :default => 'new'
      t.timestamps
    end
  end

  def self.down
    drop_table :case_requests
  end
end
