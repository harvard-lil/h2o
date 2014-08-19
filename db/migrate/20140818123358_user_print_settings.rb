class UserPrintSettings < ActiveRecord::Migration
  def change
    add_column :users, :print_titles, :boolean, :null => false, :default => true
    add_column :users, :print_dates_details, :boolean, :null => false, :default => true
    add_column :users, :print_paragraph_numbers, :boolean, :null => false, :default => true
    add_column :users, :print_annotations, :boolean, :null => false, :default => false
    add_column :users, :print_highlights, :string, :null => false, :default => 'original'
    add_column :users, :print_font_face, :string, :null => false, :default => 'dagny'
    add_column :users, :print_font_size, :string, :null => false, :default => 'small'
  end
end
