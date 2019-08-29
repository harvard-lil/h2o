require Rails.root.join("config/environments/production")

H2o::Application.configure do
  # log settings
  config.log_level = :debug

  # allow users without verified .edu addresses
  config.disable_verification = true

  # cap api settings
  config.admin_email = ['cgruppioni@law.harvard.edu']
  config.professor_verifier_email = "cgruppioni@law.harvard.edu"

  config.pandoc_export = ENV["RAILS_PANDOC_EXPORT"] == 'true'

end
