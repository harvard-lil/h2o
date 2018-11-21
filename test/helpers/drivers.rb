module H2o::Test::Helpers::Drivers
  def self.included(base)
    # Capybara.register_driver :poltergeist do |app|
    # for inspector
    Capybara.register_driver :poltergeist_debug do |app|
      Capybara::Poltergeist::Driver.new app,
        # inspector: true,
        # debug: true,
        timeout: 1.minute,
        screen_size: [1280, 800],
        window_size: [1280, 800],
        js_errors: true,
        url_whitelist: %w(://127.0.0.1:* ://localhost:*),
        extensions: %w(polyfills.js rangy-1.3.0/rangy-core.js rangy-1.3.0/rangy-textrange.js drag-mock.min.js).map {|p| File.expand_path("phantomjs/#{p}", __dir__)}
    end
    Capybara.default_max_wait_time = 10.seconds
    Capybara.save_path = Rails.root.join 'tmp/screenshots'
    # javascript_driver = base.driven_by :poltergeist
    # for inspector
    javascript_driver = base.driven_by :poltergeist_debug 
    static_driver = base.driven_by :rack_test

    base.setup do
      if ENV['CAPYBARA_SKIP_JS'] && metadata[:js] && !metadata[:focus]
        # TODO: Maybe gate Solr too? Those seem to be fast enough for now
        skip 'Automatic tests skip JavaScript. Run `bin/rails test`, or add `focus: true` to enable for this test.'
      end
    end
    base.setup do
      if metadata[:js]
        javascript_driver.use
      else
        static_driver.use
      end
    end
  end
end
