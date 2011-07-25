class AddWordsShownToCollage < ActiveRecord::Migration
  def self.up
    add_column :collages, :words_shown, :integer
  end

  def self.down
    remove_column :collages, :words_shown
  end
end
