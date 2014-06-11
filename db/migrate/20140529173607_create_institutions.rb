class CreateInstitutions < ActiveRecord::Migration
  def change
    create_table :institutions do |t|
      t.string :name, :null => false
      t.timestamps
    end
  end
end
