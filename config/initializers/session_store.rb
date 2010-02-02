# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_h2o_session',
  :secret      => 'c95ad1bf87e3baaffe0e5c02219bec39cf86aa7a1eac0519cd0c45a3f599d8aa37ce3b8bbdbceeb3d095197d72772091ddeb2982fd68161146d57b6632be690d'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
