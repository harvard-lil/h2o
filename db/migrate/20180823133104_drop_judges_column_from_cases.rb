class DropJudgesColumnFromCases < ActiveRecord::Migration[5.2]
  def change
    remove_column :cases, :judges, :jsonb
  end
end
