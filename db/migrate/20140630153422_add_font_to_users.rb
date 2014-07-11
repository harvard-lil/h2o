class AddFontToUsers < ActiveRecord::Migration
  def change
    add_column :users, :default_font, :string, :default => "futura"
  end
end
