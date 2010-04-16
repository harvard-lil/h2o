class UserSession < Authlogic::Session::Base
  self.last_request_at_threshold = 1.minute


  def self.oauth_consumer
    OAuth::Consumer.new(TWITTER_TOKEN, TWITTER_SECRET, {
        :site=>"http://twitter.com",
        :scheme             => :header,
        :http_method        => :post,
        :request_token_path => "/oauth/request_token",
        :access_token_path  => "/oauth/access_token",
        :authorize_path     => "/oauth/authenticate"
      })
  end

end