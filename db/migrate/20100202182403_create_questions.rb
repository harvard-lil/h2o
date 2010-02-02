class CreateQuestions < ActiveRecord::Migration
  def self.up
    create_table :questions do |t|
      t.integer :question_instance_id
      t.integer :user_id
      t.text :question
      t.boolean :posted_anonymously
      t.text :email
      t.text :name
      t.integer :position

      t.timestamps
    end
  end

  def self.down
    drop_table :questions
  end
end
