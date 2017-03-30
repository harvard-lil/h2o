DROPBOXCONFIG = YAML.load(File.read(File.expand_path('../../dropbox.yml', __FILE__)))
DROPBOXCONFIG.symbolize_keys!
