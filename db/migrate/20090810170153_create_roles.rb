class CreateRoles < ActiveRecord::Migration
  def self.up
    create_table :roles do |t|
      t.string   "name",              :limit => 40
      t.string   "authorizable_type", :limit => 40
      t.integer  "authorizable_id"
      t.timestamps
    end
  end

  def self.down
    drop_table :roles
  end
end
