require 'test_helper'

class UrlDomainFormatterTest < ActiveSupport::TestCase
  it "returns domain and path" do
  	passed_in_url = "https://cgruppioni.github.io/stuff/otherstuff"

  	formatted_domain = UrlDomainFormatter.format(passed_in_url)

  	assert_equal "https://cgruppioni.github.io/stuff/otherstuff/", formatted_domain
  end

  it "prepends a protocol if one is missing" do
  	passed_in_url = "cgruppioni.github.io"

  	formatted_domain = UrlDomainFormatter.format(passed_in_url)

  	assert_equal "http://cgruppioni.github.io/", formatted_domain
  end

  it "removes leading and trailing whitespace" do
    passed_in_url = "  http://cgruppioni.github.io "

    formatted_domain = UrlDomainFormatter.format(passed_in_url)

    assert_equal "http://cgruppioni.github.io/", formatted_domain
  end
end
