class RenameCasebookColumns < ActiveRecord::Migration[5.1]
  def change
    change_table :casebooks do |casebooks|
      casebooks.rename :root_id, :casebook_id
      casebooks.rename :material_id, :resource_id
      casebooks.rename :material_type, :resource_type
    end
  end
end
