class AddParagraphDisplayToUsers < ActiveRecord::Migration
  def change
    add_column :users, :default_show_paragraph_numbers, :boolean, :null => false, :default => true
  end
end
