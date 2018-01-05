class UrlDomainFormatter
  def self.format(domain)
    if !URI.parse(domain).host
      domain.prepend("http://")
    end
    
    domain
  end
end
