class RenameCaseCourtsAbbreviationColumnToNameAbbreviation < ActiveRecord::Migration[5.1]
  def change
    rename_column :case_courts, :abbreviation, :name_abbreviation
  end
end
