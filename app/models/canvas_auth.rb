class CanvasAuth
  attr_reader :oauth_params, :request_method, :request_url, :request_params

  def initialize(request)
    @oauth_params = map_oauth_params(request.params)
    @request_params = {}
    @request_method = request.method
    #@request_params = request.params
    @request_url = request.url
  end

  def valid?
    o = SimpleOAuth::Header.new(request_method, request_url, request_params, oauth_params)
    o.valid?(map_secrets)
  end

  def map_secrets
    secrets = Hash.new
    secrets[:consumer_secret] = CANVAS_CONSUMER_SECRET
    secrets
  end

  def map_oauth_params(params)
    options = Hash.new
    options[:consumer_key] = params.fetch(:oauth_consumer_key)
    options[:nonce] = params.fetch(:oauth_nonce)
    options[:timestamp] = params.fetch(:oauth_timestamp)
    options[:signature] = params.fetch(:oauth_signature)
    options[:signature_method] = params.fetch(:oauth_signature_method)
    options[:version] = params.fetch(:oauth_version)
    options
  end
end
