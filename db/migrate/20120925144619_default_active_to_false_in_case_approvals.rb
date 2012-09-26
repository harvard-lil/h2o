class DefaultActiveToFalseInCaseApprovals < ActiveRecord::Migration
  def self.up
    change_column_default(:cases, :active, false)
  end

  def self.down
    change_column_default(:cases, :active, true)
  end
end
