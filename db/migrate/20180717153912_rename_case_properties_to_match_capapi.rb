class RenameCasePropertiesToMatchCapapi < ActiveRecord::Migration[5.1]
  def up
    rename_column :cases, :short_name, :name_abbreviation
    rename_column :cases, :full_name, :name
    rename_column :case_requests, :full_name, :name
    
    rename_table :case_jurisdictions, :case_courts
    rename_column :case_requests, :case_jurisdiction_id, :case_court_id
    rename_column :cases, :case_jurisdiction_id, :case_court_id

    add_column :cases, :capapi_id, :integer
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

    add_column :case_requests, :opinions, :jsonb
    CaseRequest.where("author SIMILAR TO '%\\w%'")
      .update_all("opinions = json_build_object('majority', author)")
    remove_column :case_requests, :author

    remove_column :cases, :current_opinion # this column is unused

    puts "## NOTE ##\n"\
         "This migration changes Case property names\n"\
         "Solr should be reindexed upon completion, using Case.reindex\n"\
         "##########"
  end

  def down
    rename_column :cases, :name_abbreviation, :short_name
    rename_column :cases, :name, :full_name
    rename_column :case_requests, :name, :full_name

    rename_table :case_courts, :case_jurisdictions
    rename_column :case_requests, :case_court_id, :case_jurisdiction_id
    rename_column :cases, :case_court_id, :case_jurisdiction_id

    remove_column :cases, :capapi_id, :integer
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

    add_column :case_requests, :author, :string, limit: 150
    CaseRequest.where("author SIMILAR TO '%\\w%'")
      .update_all("author = opinions::json->>'majority'")
    remove_column :case_requests, :opinions

    add_column :cases, :current_opinion, :boolean, default: true

    puts "## NOTE ##\n"\
         "This migration changes Case property names\n"\
         "Solr should be reindexed upon completion, using Case.reindex\n"\
         "##########"
  end
end
