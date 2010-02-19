class CreateRotisseriePosts < ActiveRecord::Migration
  def self.up
    create_table :rotisserie_posts do |t|

      t.integer     :rotisserie_discussion_id
      t.integer     :round
      t.string      :title, :limit => 250, :null => false
      t.text        :output
      t.string      :session_id
      t.boolean     :active, :default => true

      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count, :position
      t.boolean :hidden

      t.timestamps
    end

    [:rotisserie_discussion_id, :round, :active, :parent_id, :position].each do |col|
      add_index :rotisserie_posts, col
    end
  end

  def self.down
    drop_table :rotisserie_posts
  end
end
