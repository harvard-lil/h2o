class AddRawContents < ActiveRecord::Migration[5.2]
  ANNOTATABLES = [Case, TextBlock]

  def up
    create_table :raw_contents do |t|  
	  t.text :content
	  t.references :source, polymorphic: true, index: { unique: true }
	  t.timestamps null: false
	end

    ANNOTATABLES.each do |klass|
      # Copy over existing, unmodified content attributes to new raw_contents table
      ActiveRecord::Base.connection.execute("INSERT INTO raw_contents (source_id, source_type, content, created_at, updated_at) SELECT id, '#{klass.name}', content, created_at, updated_at FROM #{klass.table_name}")
    end
  end

  def down
    drop_table :raw_contents
  end
end
