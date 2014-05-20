class DropInfluencesTable < ActiveRecord::Migration
  def change
    drop_table :influences
  end
end
