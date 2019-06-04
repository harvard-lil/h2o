# via: https://github.com/harvard-lil/h2o/blob/504b5e5d256c154ef50837b48fc69aa6956a9d91/lib/html_helpers.rb

module HTMLUtils
  class V5 < V4
    EFFECTIVE_DATE = Date.new(2019, 4, 24)
    class << self
      def unnest! html
        html
          .xpath('//article | //section | //aside')
          .each { |el| el.replace el.children }
        html
      end
    end
  end

  @@versions << V5
end
