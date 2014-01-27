DROPBOXCONFIG = YAML.load(File.read(File.expand_path('../../dropbox.yml', __FILE__)))
DROPBOXCONFIG.symbolize_keys!
DROPBOX_ACCESS_TOKEN_DIR = '/web/halfrek/rails3prod/docs/h2o-prod/tmp/dropbox'
