class AddCapapiIdToCaseCourts < ActiveRecord::Migration[5.1]
  def change
    add_column :case_courts, :capapi_id, :integer
  end
end
