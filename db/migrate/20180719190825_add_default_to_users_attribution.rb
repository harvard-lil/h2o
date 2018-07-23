class AddDefaultToUsersAttribution < ActiveRecord::Migration[5.1]
  def up
    change_column_null :users, :attribution, false
    change_column_default :users, :attribution, 'Anonymous'
  end

  def down
    change_column_null :users, :attribution, true
    change_column_default :users, :attribution, nil
  end
end
