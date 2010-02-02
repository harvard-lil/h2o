class CreateQuestions < ActiveRecord::Migration
  def self.up
    create_table :questions do |t|
      t.integer :question_instance_id
      t.integer :user_id
      t.string :question, :limit => 10000, :null => false
      t.boolean :posted_anonymously, :default => false
      t.string :email, :limit => 250
      t.string :name, :limit => 250
      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count, :position

      t.timestamps
    end
  end

  def self.down
    drop_table :questions
  end
end
