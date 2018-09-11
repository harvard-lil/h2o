class UrlDomainFormatter
  def self.format(domain)
    uri = URI.parse(domain)
    "#{uri.scheme || 'http'}://#{uri.host + uri.path}/"
  end
end
