class RemoveContentFromCaseCourts < ActiveRecord::Migration[5.1]
  def change
    remove_column :case_courts, :content, :text
  end
end
