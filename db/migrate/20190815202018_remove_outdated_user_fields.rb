class RemoveOutdatedUserFields < ActiveRecord::Migration[5.2]
  def up 
    remove_column :users, :default_font_size
    remove_column :users, :canvas_id
    remove_column :users, :default_font
    remove_column :users, :print_titles
    remove_column :users, :print_dates_details
    remove_column :users, :print_paragraph_numbers
    remove_column :users, :print_annotations
    remove_column :users, :print_highlights
    remove_column :users, :print_font_face
    remove_column :users, :print_font_size
    remove_column :users, :default_show_comments
    remove_column :users, :default_show_paragraph_numbers
    remove_column :users, :hidden_text_display
    remove_column :users, :print_links
    remove_column :users, :toc_levels
    remove_column :users, :print_export_format
    remove_column :users, :image_file_name
    remove_column :users, :image_content_type
    remove_column :users, :image_file_size
    remove_column :users, :image_updated_at
  end

  def down
    add_column :users, :default_font_size, :integer, default: "10"
    add_column :users, :canvas_id, :string
    add_column :users, :default_font, :string, default: "futura"
    add_column :users, :print_titles, :boolean, default: true, null: false
    add_column :users, :print_dates_details, :boolean, default: true, null: false
    add_column :users, :print_paragraph_numbers, :boolean, default: true, null: false
    add_column :users, :print_annotations, :boolean, default: false, null: false
    add_column :users, :print_highlights, :string, default: "original", null: false
    add_column :users, :print_font_face, :string, default: "dagney", null: false
    add_column :users, :print_font_size, :string, default: "small", null: false
    add_column :users, :default_show_comments, :boolean, default: false, null: false, default: false, null: false
    add_column :users, :default_show_paragraph_numbers, :boolean, default: true, null: false
    add_column :users, :hidden_text_display, :boolean, default: false, null: false
    add_column :users, :print_links, :boolean, default: true, null: false
    add_column :users, :toc_levels, :string, default: "", null: false
    add_column :users, :print_export_format, :string, default: "", null: false
    add_column :users, :image_file_name, :string
    add_column :users, :image_content_type, :string
    add_column :users, :image_file_size, :integer
    add_column :users, :image_updated_at, :datetime
  end
end
