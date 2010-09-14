require 'migration_helpers'
class ModifyCollagesForAncestry < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    [:children_count, :ancestors_count, :descendants_count, :position, :hidden].each do |col|
      remove_column :collages, col
    end
    add_column :collages, :ancestry, :string
    add_index :collages, :ancestry
    Collage.build_ancestry_from_parent_ids!
    Collage.check_ancestry_integrity!
    remove_column :collages, :parent_id
  end

  def self.down
    add_column :collages, :parent_id, :integer
    add_column :collages, :children_count, :integer
    add_column :collages, :ancestors_count, :integer
    add_column :collages, :descendants_count, :integer
    add_column :collages, :position, :integer
    add_column :collages, :hidden, :boolean
    create_acts_as_category_indexes(Collage)
  end
end
