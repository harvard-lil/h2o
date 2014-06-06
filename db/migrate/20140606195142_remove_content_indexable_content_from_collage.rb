class RemoveContentIndexableContentFromCollage < ActiveRecord::Migration
  def change
    remove_column :collages, :content
    remove_column :collages, :indexable_content
  end
end
