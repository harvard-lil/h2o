class CreateReplies < ActiveRecord::Migration
  def self.up
    create_table :replies do |t|
      t.integer :question_id
      t.integer :user_id
      t.text :reply
      t.text :email
      t.text :name
      t.boolean :posted_anonymously
      t.integer :position

      t.timestamps
    end
  end

  def self.down
    drop_table :replies
  end
end
