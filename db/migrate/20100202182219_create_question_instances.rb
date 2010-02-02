class CreateQuestionInstances < ActiveRecord::Migration
  def self.up
    create_table :question_instances do |t|
      t.string :name, :limit => 250, :null => false
      t.integer :user_id
      t.integer :project_id
      t.string :password, :limit => 128
      t.integer :featured_question_count
      t.integer :featured_question_timeout
      t.integer :old_question_timeout
      t.text :description, :limit => 2000

      t.timestamps
    end
    [:name, :user_id, :project_id, :
  end

  def self.down
    drop_table :question_instances
  end
end
