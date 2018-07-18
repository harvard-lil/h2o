# TODO:
# - where does current_opinion fit in this?
# - where are the judges represented in the existing Case?
# - what to do with header_html?
# - court vs jurisdiction in current schema
# - do we need to add capapi's reporter?
# - how to handle volumes? Looks like h2o has them on cites, but capapi on cases
# - add indexes

class RenameCasePropertiesToMatchCapapi < ActiveRecord::Migration[5.1]
  def up
    rename_column :cases, :short_name, :name_abbreviation
    rename_column :cases, :full_name, :name

    add_column :cases, :first_page, :integer
    add_column :cases, :last_page, :integer
    add_column :cases, :judges, :jsonb

    # Normalize attorneys
    add_column :cases, :attorneys, :jsonb
    Case.where("lawyer_header SIMILAR TO '%\\w%'")
      .update_all("attorneys = json_build_array(lawyer_header)")
    remove_column :cases, :lawyer_header

    # Normalize parties
    add_column :cases, :parties, :jsonb
    Case.where("party_header SIMILAR TO '%\\w%'")
      .update_all("parties = json_build_array(party_header)")
    remove_column :cases, :party_header

    # Normalize opinions
    add_column :cases, :opinions, :jsonb
    Case.where("author SIMILAR TO '%\\w%'")
      .update_all("opinions = json_build_object('majority', author)")
    remove_column :cases, :author
  end

  def down
    rename_column :cases, :name_abbreviation, :short_name
    rename_column :cases, :name, :full_name

    remove_column :cases, :first_page
    remove_column :cases, :last_page
    remove_column :cases, :judges

    # Denomalize attorneys
    add_column :cases, :lawyer_header, :string, limit: 2048
    Case.where.not(attorneys: nil)
      .update_all("lawyer_header = attorneys::json->>0")
    remove_column :cases, :attorneys

    # Denomalize parties
    add_column :cases, :party_header, :string, limit: 10240
    Case.where.not(parties: nil)
      .update_all("party_header = parties::json->>0")
    remove_column :cases, :parties

    # Denormalize opinions
    add_column :cases, :author, :string, limit: 150
    Case.where.not(opinions: nil)
      .update_all("author = opinions::json->>'majority'")
    remove_column :cases, :opinions
  end
end
