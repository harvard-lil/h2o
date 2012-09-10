class AddJournalArticleTypes < ActiveRecord::Migration
  def self.up
    JournalArticleType.create(:name => "Print Edition – Article")
    JournalArticleType.create(:name => "Print Edition – Student Note")
    JournalArticleType.create(:name => "Print Edition – Student Commentary")
    JournalArticleType.create(:name => "Print Edition – Opinion")
    JournalArticleType.create(:name => "Print Edition – Recent Development")
    JournalArticleType.create(:name => "Print Edition – Book Review")
    JournalArticleType.create(:name => "Print Edition – Symposium Forum")
    JournalArticleType.create(:name => "Print Edition – Other Type")
    JournalArticleType.create(:name => "Online – Article")
    JournalArticleType.create(:name => "Online – Student Note")
    JournalArticleType.create(:name => "Online – Student Commentary")
    JournalArticleType.create(:name => "Online – Opinion")
    JournalArticleType.create(:name => "Online – Recent Development")
    JournalArticleType.create(:name => "Online – Book Review")
    JournalArticleType.create(:name => "Online – Symposium Forum")
    JournalArticleType.create(:name => "Online – Other Type")
  end

  def self.down
    JournalArticleType.destroy_all
  end
end
