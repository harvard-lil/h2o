class UrlDomainFormatter
  def self.format(domain)
    uri = URI.parse(domain.strip)

    if uri.host.present?
      "#{uri.scheme || 'http'}://#{uri.host + uri.path}/"
    else
      "#{uri.scheme || 'http'}://#{uri.path}/"
    end
  end
end
