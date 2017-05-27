class CreateCasebooks < ActiveRecord::Migration[5.1]
  def change
    create_table :casebooks do |t|
      t.string :title, null: true
      t.string :slug, null: true
      t.string :subtitle, null: true
      t.text :headnote, null: true

      t.boolean :public, null: false, default: true

      t.references :root, null: true, index: true, foreign_key: {to_table: :casebooks}
      t.integer :ordinals, null: false, array: true, default: []

      t.references :copy_of, null: true, index: true, foreign_key: {to_table: :casebooks}
      t.boolean :is_alias, null: true

      t.references :material, polymorphic: true, null: true, index: true

      t.timestamps
    end

    add_index :casebooks, [:root_id, :ordinals], using: 'gin'
  end
end
