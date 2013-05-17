class CreateDefaults < ActiveRecord::Migration
  def self.up
    create_table :defaults do |t|
      t.string :name, :limit => 1024
      t.string :title, :null => false
      t.string :url, :null => false
      t.string :description, :limit => 5.megabytes
      t.boolean :active, :default => true
      t.boolean :public, :default => true
      t.integer :karma
      t.timestamps
    end

    add_column :item_defaults, :actual_object_type, :string
    add_column :item_defaults, :actual_object_id, :integer

    ItemDefault.all.each do |i|
      link = Default.new(:name => i.name, :title => i.title, :url => i.url, :description => i.description, :created_at => i.created_at)
      link.accepts_role!(:owner, i.owners.first) if i.owners.present?
      link.accepts_role!(:creator, i.owners.first) if i.owners.present?
      if link.save
        i.actual_object = link
        i.save
      end
    end
  end

  def self.down
    drop_table :defaults

    remove_column :item_defaults, :actual_object_type
    remove_column :item_defaults, :actual_object_id
  end
end
