class CreateInstitutionsUsers < ActiveRecord::Migration
  def change
    create_table :institutions_users, :id => false, :force => true do |t|
      t.references  :institution, :null => false
      t.references  :user, :null => false
    end

    connection.execute("INSERT INTO roles (name, created_at, updated_at) VALUES ('rep', NOW(), NOW())")
  end
end
