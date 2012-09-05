class CreateJournalArticles < ActiveRecord::Migration
  def self.up
    create_table :journal_articles do |t|
      t.string :name, :limit => 255, :null => false

      if connection.adapter_name.downcase == 'postgresql'
        t.string :description, :limit => 5.megabytes, :null => false
      else
        t.text :description, :limit => 5.megabytes, :null => false
      end

      t.date :publish_date, :null => false
      t.string :subtitle

      t.string :author, :null => false
      if connection.adapter_name.downcase == 'postgresql'
        t.string :author_description, :limit => 5.megabytes
      else
        t.text :author_description, :limit => 5.megabytes
      end

      t.string :volume, :null => false
      t.string :issue, :null => false
      t.string :page, :null => false
      t.string :bluebook_citation, :null => false
      t.integer :journal_article_type_id, :null => false
      t.string :article_series_title
      if connection.adapter_name.downcase == 'postgresql'
        t.string :article_series_description, :limit => 5.megabytes
      else
        t.text :article_series_description, :limit => 5.megabytes
      end

      t.string :pdf_url
      t.string :image
      t.string :attribution, :null => false
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
