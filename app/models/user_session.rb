class UserSession < Authlogic::Session::Base

  def self.oauth_consumer
    OAuth::Consumer.new("yM5O3JWGMPJveOwENu65A", "fgiAmv8QlplWUNDhiOfDUCubgOH5HVPHhrPAnzQ2Eo", {
        :site=>"http://twitter.com",
        :scheme             => :header,
        :http_method        => :post,
        :request_token_path => "/oauth/request_token",
        :access_token_path  => "/oauth/access_token",
        :authorize_path     => "/oauth/authenticate"
      })
  end

end