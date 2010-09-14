require 'migration_helpers'
class ModifyAnnotationsForAncestry < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    [:children_count, :ancestors_count, :descendants_count, :position, :hidden].each do |col|
      remove_column :annotations, col
    end
    add_column :annotations, :ancestry, :string
    add_index :annotations, :ancestry
    Annotation.build_ancestry_from_parent_ids!
    Annotation.check_ancestry_integrity!
    remove_column :annotations, :parent_id
  end

  def self.down
    add_column :annotations, :parent_id, :integer
    add_column :annotations, :children_count, :integer
    add_column :annotations, :ancestors_count, :integer
    add_column :annotations, :descendants_count, :integer
    add_column :annotations, :position, :integer
    add_column :annotations, :hidden, :boolean
    create_acts_as_category_indexes(Annotation)
  end
end
