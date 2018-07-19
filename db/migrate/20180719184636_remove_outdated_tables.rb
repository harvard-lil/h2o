class RemoveOutdatedTables < ActiveRecord::Migration[5.1]
  def up
    drop_table :brain_busters
    drop_table :case_ingestion_requests
    drop_table :collages_user_collections
    drop_table :color_mappings
    drop_table :defects
    drop_table :deleted_items
    drop_table :imports
    drop_table :institutions
    drop_table :institutions_users
    drop_table :journal_article_types
    drop_table :journal_article_types_journal_articles
    drop_table :journal_articles
    drop_table :locations
    drop_table :question_instances
    drop_table :questions
    drop_table :responses
    drop_table :rotisserie_assignments
    drop_table :rotisserie_discussions
    drop_table :rotisserie_instances
    drop_table :rotisserie_posts
    drop_table :rotisserie_trackers
    drop_table :votes
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
