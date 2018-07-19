class AddDefaultToUsersAttribution < ActiveRecord::Migration[5.1]
  def change
    change_column_default :users, :attribution, 'Anonymous'
  end
end
