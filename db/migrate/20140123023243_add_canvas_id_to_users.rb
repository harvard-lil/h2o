class AddCanvasIdToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :canvas_id, :string
  end

  def self.down
    remove_column :users, :canvas_id
  end
end
