class RemoveSentInCasesListColumnFromCases < ActiveRecord::Migration[5.1]
  def change
    remove_column :cases, :sent_in_cases_list, :boolean
  end
end
