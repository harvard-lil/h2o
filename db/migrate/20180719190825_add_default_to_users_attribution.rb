class AddDefaultToUsersAttribution < ActiveRecord::Migration[5.1]
  def up
    default = 'Anonymous'
    User.where(attribution: nil).update_all(attribution: default)
    change_column_null :users, :attribution, false
    change_column_default :users, :attribution, default
  end

  def down
    change_column_null :users, :attribution, true
    change_column_default :users, :attribution, nil
  end
end
