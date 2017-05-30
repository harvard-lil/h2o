class RemoveIndexOnCasesFullName < ActiveRecord::Migration[5.1]
  def change
    remove_index :cases, :full_name
  end
end
