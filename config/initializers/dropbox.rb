DROPBOXCONFIG = YAML.load(File.read(File.expand_path('../../dropbox.yml', __FILE__)))
DROPBOXCONFIG.symbolize_keys!

if Rails.env == 'production'
  DROPBOX_ACCESS_TOKEN_DIR = '/web/halfrek/rails3prod/docs/h2o-prod/tmp/dropbox'
else
  DROPBOX_ACCESS_TOKEN_DIR = '/web/murk/home/sskardal/sskardal01/tmp/dropbox'
end
