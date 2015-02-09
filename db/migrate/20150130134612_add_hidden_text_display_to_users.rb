class AddHiddenTextDisplayToUsers < ActiveRecord::Migration
  def change
    add_column :users, :hidden_text_display, :boolean, :null => false, :default => false
  end
end
