class RemoveUserFromAnnotation < ActiveRecord::Migration
  def change
    remove_column :annotations, :user_id
  end
end
