class CreateRotisserieDiscussions < ActiveRecord::Migration
  def self.up
    create_table :rotisserie_discussions do |t|
      t.integer     :rotisserie_instance_id
      t.string      :title, :limit => 250, :null => false
      t.text        :output
      t.text        :description
      t.text        :notes
      t.integer     :round_length, :default => 2
      t.integer     :final_round, :default => 2
      t.datetime    :start_date
      t.string      :session_id
      t.boolean     :active, :default => true
      t.timestamps
    end

    [:rotisserie_instance_id, :title, :active].each do |col|
      add_index :rotisserie_discussions, col
    end

  end

  def self.down
    drop_table :rotisserie_discussions
  end
end
