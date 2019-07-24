# via: https://github.com/harvard-lil/h2o/blob/504b5e5d256c154ef50837b48fc69aa6956a9d91/lib/html_helpers.rb

module HTMLUtils
  class V6 < V5
    EFFECTIVE_DATE = Date.new(2019, 5, 26)
    class << self
      def parse html
        Nokogiri.HTML5(html)
      end
    end
  end

  @@versions << V6
end
