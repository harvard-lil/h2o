Htmltoword.configure do |config|
  config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/with-annotations'
  config.custom_xslt_path = Rails.root.join 'lib/htmltoword/xslt/no-annotations'
  config.default_templates_path = Rails.root.join 'lib/htmltoword/templates'
end
