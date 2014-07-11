class ResetFontDefault < ActiveRecord::Migration
  def self.up
    change_column_default :users, :default_font_size, 10
  end

  def self.down
    change_column_default :users, :default_font_size, 16
  end
end
