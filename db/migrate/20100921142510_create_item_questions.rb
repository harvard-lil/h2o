class CreateItemQuestions < ActiveRecord::Migration
  def self.up
    create_table :item_questions do |t|
      t.string :title
      t.string :output_text
      t.string :url
      t.text :description
      t.boolean :active
      t.boolean :public

      t.timestamps
    end
    [:active, :public, :url].each do |col|
      add_index :item_questions, col
    end
  end

  def self.down
    drop_table :item_questions
  end
end
