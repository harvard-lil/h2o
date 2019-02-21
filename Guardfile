require 'rake'
::Rake.application.init
::Rake.application.load_rakefile

# Run `bundle install` whenever Gemfile changes.
guard :bundler do
  watch('Gemfile')
end

guard :yarn do
  watch('package.json')
end

# Run local solr on launch and whenever sunspot config changes.
%w(development test).each do |env|
  guard 'sunspot', environment: env do
    # watch('Gemfile.lock') # gems don't usually affect sunspot, so be careful to check this manually
    watch('config/sunspot.yml')
  end
end

# Reloads spring whenever configs change.
guard :spring, bundler: true, environments: %w(development) do
  watch('Gemfile.lock')
  watch(%r{^config/})
end

guard :process, name: "Webpack Dev Server", command: "bin/webpack-dev-server", env: {"RAILS_ENV" => "development"} do
  watch('config/webpacker.yml')
end

# Restart the dev server whenever configs change. (The dev server will automatically reload app code.)
guard :rails, port: (ENV['RAILS_PORT'] || 8000), host: '0.0.0.0', server: :puma do
  watch('Gemfile.lock')
  watch(%r{^(config|lib)/.*})
  ignore %r{^lib/locales/(.*)\.yml}
end
