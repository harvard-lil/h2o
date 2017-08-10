class UrlDomainFormatter
  def self.format(domain)
    if !URI.parse(domain).host
      domain.prepend("http://")
    end
    # remove file path
    domain = URI.join(domain, "/").to_s
    
    domain
  end
end
