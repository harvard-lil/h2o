class UserIdCleanup < ActiveRecord::Migration
  def self.up
    [:annotations, :case_requests, :cases, :collages,
     :defaults, :medias, :playlists, :text_blocks,
     :rotisserie_discussions, :rotisserie_instances, :rotisserie_posts].each do |t|
      add_column t, :user_id, :integer, :null => false, :default => 0
    end
    conxn = ActiveRecord::Base.connection
    results = conxn.select_rows("SELECT r.authorizable_type, r.authorizable_id, ru.user_id
      FROM roles r 
      JOIN roles_users ru ON ru.role_id = r.id 
      WHERE r.name = 'owner' 
      AND r.authorizable_id IS NOT NULL")
    results.each do |row|
      conxn.execute("UPDATE #{row[0].tableize} SET user_id = #{row[2]} WHERE id = #{row[1]}") 
    end
    conxn.execute("DELETE FROM roles_users WHERE role_id IN (SELECT id FROM roles WHERE name = 'owner')")
    conxn.execute("DELETE FROM roles WHERE name = 'owner'")
  end

  def self.down
    [:annotations, :case_requests, :cases, :collages,
     :defaults, :journal_articles, :medias, :playlists, :text_blocks,
     :rotisserie_discussions, :rotisserie_instances, :rotisserie_posts].each do |t|
      remove_column t, :user_id
    end

    # No reverse migration written for role management
  end
end
