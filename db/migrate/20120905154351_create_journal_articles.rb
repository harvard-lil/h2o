class CreateJournalArticles < ActiveRecord::Migration
  def self.up
    create_table :journal_articles do |t|
      t.string :name, :limit => 255, :null => false

      if connection.adapter_name.downcase == 'postgresql'
        t.string :description, :limit => 5.megabytes, :null => false
      else
        t.text :description, :limit => 5.megabytes, :null => false
      end

      t.date :publish_date
      t.string :subtitle

      t.string :author
      if connection.adapter_name.downcase == 'postgresql'
        t.string :author_description, :limit => 5.megabytes, :null => false
      else
        t.text :author_description, :limit => 5.megabytes, :null => false
      end

      t.string :volume
      t.string :issue
      t.string :page
      t.string :bluebook_citation
      t.integer :journal_article_type_id
      t.string :article_series_title
      t.string :article_series_description
      t.string :pdf_url
      t.string :image
      t.string :attribution
      t.string :attribution_url

      if connection.adapter_name.downcase == 'postgresql'
        t.string :video_embed, :limit => 5.megabytes, :null => false
      else
        t.text :video_embed, :limit => 5.megabytes, :null => false
      end
      
      t.boolean :active, :default => true
      t.boolean :public, :default => true
      t.timestamps
    end
    
    [:name,:created_at,:updated_at].each do|col|
      add_index :text_blocks, col
    end
  end

  def self.down
    drop_table :journal_articles
  end
end
