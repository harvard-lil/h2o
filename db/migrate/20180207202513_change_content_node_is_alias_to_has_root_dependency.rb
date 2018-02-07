class ChangeContentNodeIsAliasToHasRootDependency < ActiveRecord::Migration[5.1]
  def up
    rename_column :content_nodes, :is_alias, :has_root_dependency
  end

  def down
    rename_column :content_nodes, :has_root_dependency, :is_alias
  end
end
