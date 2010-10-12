class CreateAnnotationWordCountCache < ActiveRecord::Migration
  def self.up
    add_column :annotations, :annotation_word_count, :integer
  end

  def self.down
    remove_column :annotations, :annotation_word_count
  end
end
