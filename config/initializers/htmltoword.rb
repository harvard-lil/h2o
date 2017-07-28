Htmltoword.configure do |config|
  config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt'
  config.default_templates_path = Rails.root.join 'lib/htmltoword/templates'
end
