class AddNullableToUsersAttribution < ActiveRecord::Migration[5.1]
  def change
    change_column_null :users, :attribution, false
  end
end
