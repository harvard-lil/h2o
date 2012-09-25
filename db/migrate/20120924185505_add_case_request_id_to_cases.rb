class AddCaseRequestIdToCases < ActiveRecord::Migration
  def self.up
    add_column :cases, :case_request_id, :integer
  end

  def self.down
    remove_column :cases, :case_request_id
  end
end
