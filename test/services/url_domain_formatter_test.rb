require "service_test_case"

class UrlDomainFormatter < ServiceTestCase
  scenario "returns only the domain" do
  	passed_in_url = "https://cgruppioni.github.io/stuff/otherstuff"

  	formatted_domain = UrlDomainFormatter.format(passed_in_url)

  	assert_equal formatted_domain, "https://cgruppioni.github.io/"
  end

  scenario "prepends a protocol if one is missing" do
  	passed_in_url = "cgruppioni.github.io"

  	formatted_domain = UrlDomainFormatter.format(passed_in_url)

  	assert_equal formatted_domain, "http://cgruppioni.github.io/"
  end
end
