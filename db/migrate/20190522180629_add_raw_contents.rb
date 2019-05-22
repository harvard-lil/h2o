class AddRawContents < ActiveRecord::Migration[5.2]
  def up
    create_table :raw_contents do |t|  
      t.text :content
      t.references :source, polymorphic: true, index: { unique: true }
      t.timestamps null: false
    end

    [Case, TextBlock].each do |entity|
      ActiveRecord::Base.connection.execute("INSERT INTO raw_contents (source_id, source_type, content, created_at, updated_at) SELECT id, '#{entity.name}', content, created_at, updated_at FROM #{entity.table_name}")
    end
  end

  def down
    drop_table :raw_contents
  end
end
