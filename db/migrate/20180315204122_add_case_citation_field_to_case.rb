class AddCaseCitationFieldToCase < ActiveRecord::Migration[5.1]
  def up
    add_column :cases, :primary_case_citation, :string, index: true
  end

  def down
    remove_column :cases, :primary_case_citation
  end
end
