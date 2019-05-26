# via: https://github.com/harvard-lil/h2o/blob/a6bc3388fe0cde62fd423dd0e457649a582c232c/lib/html_helpers.rb

module HTMLFormatter
  class V2 < V1
    EFFECTIVE_DATE = Date.new(2018, 8, 21)
    class << self
      def unwrap! html
        html
          .xpath('//div | //article | //section | //aside')
          .each { |el| el.replace el.children }
        html
      end
    end
  end

  @@versions << V2
end
