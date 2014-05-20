class UserSession < Authlogic::Session::Base
  self.last_request_at_threshold = 10.minutes
  allow_http_basic_auth false
end
