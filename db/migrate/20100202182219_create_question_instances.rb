require 'migration_helpers'
class CreateQuestionInstances < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :question_instances do |t|
      t.string :name, :limit => 250, :null => false
      t.integer :user_id
      t.integer :project_id
      t.string :password, :limit => 128
      t.integer :featured_question_count, :default => 2
      t.string :description, :limit => 2000

      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count, :position
      t.boolean :hidden
      t.timestamps
    end

    create_acts_as_category_indexes(QuestionInstance)

    [:user_id, :project_id].each do |col|
      add_index :question_instances, col
    end

    add_index :question_instances, :name, :unique => true
    add_index :question_instances, [:project_id, :position], :unique => true
  end

  def self.down
    drop_table :question_instances
  end
end
