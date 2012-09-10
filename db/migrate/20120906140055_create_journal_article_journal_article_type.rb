class CreateJournalArticleJournalArticleType < ActiveRecord::Migration
  def self.up
    create_table :journal_article_types_journal_articles, :id => false do |t|
      t.references :journal_article
      t.references :journal_article_type
    end
  end

  def self.down
    drop_table :journal_article_types_journal_articles
  end
end
