class AddSentInCaseListToCases < ActiveRecord::Migration
  def self.up
    add_column :cases, :sent_in_cases_list, :boolean, :default => false
  end

  def self.down
    remove_column :cases, :sent_in_cases_list
  end
end