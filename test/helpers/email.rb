module H2o::Test::Helpers::Email
  def self.included(base)
      ActionMailer::Base.perform_deliveries = true

      base.setup do
        if Capybara.current_session.server
          ActionMailer::Base.default_url_options = {
            host: Capybara.current_session.server.host,
            port: Capybara.current_session.server.port
          }
        end
      end
  end

  def wait_until wait: Capybara.default_max_wait_time, &block
    Timeout.timeout(wait) do
      until block.call()
        sleep 0.5
      end
    end
  end
  def assert_mail_to address, content=//
    matching_emails = ActionMailer::Base.deliveries
  end
  def assert_sends_emails n, **args
    wait_until(**args) {ActionMailer::Base.deliveries.length == n}
  end
end
