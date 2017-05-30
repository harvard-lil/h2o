class RemoveFullNameLimitInCases < ActiveRecord::Migration[5.1]
  def change
  	change_column :cases, :full_name, :string 
  end
end
