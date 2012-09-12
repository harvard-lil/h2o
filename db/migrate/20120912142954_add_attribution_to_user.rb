class AddAttributionToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :attribution, :string
  end

  def self.down
    remove_column :users, :attribution
  end
end
