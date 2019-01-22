module H2o::Test::Helpers::Drivers
  def self.included(base)
    Capybara.default_max_wait_time = 10.seconds
    Capybara.save_path = Rails.root.join 'tmp/screenshots'
    javascript_driver = base.driven_by :selenium_chrome_headless
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
