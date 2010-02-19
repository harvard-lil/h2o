class CreateRotisserieAssignments < ActiveRecord::Migration
  def self.up
    create_table :rotisserie_assignments do |t|
      t.integer   :user_id
      t.integer   :rotisserie_discussion_id
      t.integer   :rotisserie_post_id
      t.integer   :round

      t.timestamps
    end

    [:user_id, :rotisserie_discussion_id, :rotisserie_post_id, :round].each do |col|
      add_index :rotisserie_assignments, col
    end
  end

  def self.down
    drop_table :rotisserie_assignments
  end
end
