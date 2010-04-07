class AddUserAdditionalFields < ActiveRecord::Migration
    def self.up
      add_column :users, :email_address, :string, :limit => 255
      add_column :users, :tz_name, :string, :limit => 255
      add_index :email_address, :tz_name
    end

    def self.down
      remove_column :users, :email_address
      remove_column :users, :tz_name
    end

end
