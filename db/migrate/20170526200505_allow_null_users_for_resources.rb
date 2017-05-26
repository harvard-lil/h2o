class AllowNullUsersForResources < ActiveRecord::Migration[5.1]
  def change
    change_column_null :cases, :user_id, :true
    change_column_null :text_blocks, :user_id, :true
    change_column_null :defaults, :user_id, :true
  end
end
