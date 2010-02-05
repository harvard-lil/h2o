class CreateReplies < ActiveRecord::Migration
  def self.up
    create_table :replies do |t|
      t.integer :question_id, :null => false
      t.integer :user_id
      t.text :reply, :null => false, :limit => 1000
      t.text :email, :limit => 250
      t.text :name, :limit => 250
      t.boolean :posted_anonymously, :default => false
      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count, :position
      t.timestamps
    end
    [:user_id, :question_id, :parent_id, :email, :position].each do |col|
      add_index :replies, col
    end
    # Again - enforce logical constraints.
    add_index :replies, [:question_id, :position], :unique => true
    add_index :replies, [:user_id, :question_id, :position], :unique => true
  end

  def self.down
    drop_table :replies
  end
end
