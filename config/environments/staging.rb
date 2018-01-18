require Rails.root.join("config/environments/production")

H2o::Application.configure do
  # log settings
  config.log_level = :debug

  # allow users without verified .edu addresses
  config.disable_verification = true

  # cap api settings
  # config.admin_email = 'cgruppioni@law.harvard.edu'
  # config.cap_api_key = '2c62c54b47e507b2eee20a70f29f1b4ae0ccd1a3'
  config.professor_verification_email = "cgruppioni@law.harvard.edu"
end
