class AddFeedbackToTextBlocksCollages < ActiveRecord::Migration
  def change
    add_column :collages, :enable_feedback, :boolean, :null => false, :default => true
    add_column :collages, :enable_discussions, :boolean, :null => false, :default => false
    add_column :collages, :enable_responses, :boolean, :null => false, :default => false
    add_column :text_blocks, :enable_feedback, :boolean, :null => false, :default => true
    add_column :text_blocks, :enable_discussions, :boolean, :null => false, :default => false
    add_column :text_blocks, :enable_responses, :boolean, :null => false, :default => false
  end
end
