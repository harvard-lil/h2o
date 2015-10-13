class AddErrorFeedbackDiscussToAnnotation < ActiveRecord::Migration
  def change
    remove_column :annotations, :public
    remove_column :annotations, :active
    remove_column :annotations, :word_count
    remove_column :annotations, :annotation_word_count
    remove_column :annotations, :ancestry

    add_column :annotations, :error, :boolean, :null => false, :default => false 
    add_column :annotations, :feedback, :boolean, :null => false, :default => false 
    add_column :annotations, :discussion, :boolean, :null => false, :default => false

    add_column :annotations, :user_id, :integer
  end
end
