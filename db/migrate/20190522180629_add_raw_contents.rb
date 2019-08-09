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

      # Apply HTML cleansing / munging to existing content attributes
      klass.find_each do |instance|
        # use update_column to avoid touching the timestamps
        instance.update_column :content, HTMLUtils.cleanse(instance.content)
      end
    end
  end

  def down
    ANNOTATABLES.each do |klass|
      ActiveRecord::Base.connection.execute("UPDATE #{klass.table_name} SET content = raw_contents.content FROM raw_contents WHERE raw_contents.source_type = '#{klass.name}' AND #{klass.table_name}.id = raw_contents.source_id")
    end

    drop_table :raw_contents
  end
end
