class CreateJournalArticleTypes < ActiveRecord::Migration
  def self.up
    create_table :journal_article_types do |t|
      t.string :name
      t.timestamps
    end
  end

  def self.down
    drop_table :journal_article_types
  end
end
