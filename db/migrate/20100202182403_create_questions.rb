class CreateQuestions < ActiveRecord::Migration
  def self.up
    create_table :questions do |t|
      t.integer :question_instance_id, :null => false
      t.integer :user_id
      t.string :question, :limit => 10000, :null => false
      t.boolean :posted_anonymously, :default => false
      t.string :email, :limit => 250
      t.string :name, :limit => 250
      t.boolean :sticky, :default => false
      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count, :position
      t.boolean :hidden

      t.timestamps
    end

    [:user_id, :question_instance_id, :parent_id, :position, :email, :sticky].each do |col|
      add_index :questions, col
    end
    #Enforce some logical constraints - a questions CAN'T have a duplicate position 
    #in the context of a question_instance.
    #Ditto for the action of a user asking a question in the context of a question_instance.
    add_index :questions, [:question_instance_id, :parent_id, :position], :unique => true, :name => 'unique_in_question_instance'
    add_index :questions, [:user_id,:question_instance_id, :parent_id, :position], :unique => true, :name => 'unique_user_in_question_instance'
  end

  def self.down
    drop_table :questions
  end
end
