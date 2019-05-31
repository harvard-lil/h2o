class AddAnnotationsCounterToCasesAndTextBlocks < ActiveRecord::Migration[5.2]
  ANNOTATABLES = [Case, TextBlock]

  def up
    ANNOTATABLES.each do |klass|
      add_column klass.table_name, :annotations_count, :integer, null: false, default: 0

      ActiveRecord::Base.connection.execute <<-SQL.squish
        UPDATE #{klass.table_name}
        SET annotations_count = (SELECT COUNT(*) FROM "content_annotations" INNER JOIN "content_nodes" ON "content_annotations"."resource_id" = "content_nodes"."id" WHERE "content_nodes"."casebook_id" IS NOT NULL AND "content_nodes"."casebook_id" IS NOT NULL AND "content_nodes"."resource_id" IS NOT NULL AND "content_nodes"."resource_id" = #{klass.table_name}.id AND "content_nodes"."resource_type" = '#{klass.name}')
      SQL
    end
  end

  def down
    ANNOTATABLES.each { |klass| remove_column klass.table_name, :annotations_count }
  end
end
