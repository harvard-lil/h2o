class DropVotesTable < ActiveRecord::Migration[5.1]
  def up
    drop_table :votes
  end

  def down
    create_table "votes" do |t|
      t.boolean "vote", default: false
      t.integer "voteable_id"
      t.string "voteable_type", limit: 255
      t.integer "voter_id"
      t.string "voter_type", limit: 255
      t.datetime "created_at"
      t.datetime "updated_at"
      t.index ["voteable_id", "voteable_type"], name: "fk_voteables"
      t.index ["voter_id", "voter_type", "voteable_id", "voteable_type"], name: "uniq_one_vote_only", unique: true
      t.index ["voter_id", "voter_type"], name: "fk_voters"
    end
  end
end
