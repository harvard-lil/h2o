class UserSession < Authlogic::Session::Base
  self.last_request_at_threshold = 10.minutes
end
