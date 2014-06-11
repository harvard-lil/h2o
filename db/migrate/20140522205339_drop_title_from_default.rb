class DropTitleFromDefault < ActiveRecord::Migration
  def change
    remove_column :defaults, :title
  end
end
