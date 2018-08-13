require "service_test_case"

class UrlDomainFormatterTest < ServiceTestCase
  scenario "returns only the domain" do
  	passed_in_url = "https://cgruppioni.github.io/stuff/otherstuff"

  	formatted_domain = UrlDomainFormatter.format(passed_in_url)

  	assert_equal "https://cgruppioni.github.io/", formatted_domain
  end

  scenario "prepends a protocol if one is missing" do
  	passed_in_url = "cgruppioni.github.io"

  	formatted_domain = UrlDomainFormatter.format(passed_in_url)

  	assert_equal "http://cgruppioni.github.io/", formatted_domain
  end
end
