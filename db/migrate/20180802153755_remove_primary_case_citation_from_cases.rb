class RemovePrimaryCaseCitationFromCases < ActiveRecord::Migration[5.1]
  def change
    remove_column :cases, :primary_case_citation, :string
  end
end
