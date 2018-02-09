class SetUnpublishedRevisionValueToNullTrue < ActiveRecord::Migration[5.1]
  def up
    change_column :unpublished_revisions, :value, :string, null: true
  end

  def down
    change_column :unpublished_revisions, :value, :string, null: false
  end
end
