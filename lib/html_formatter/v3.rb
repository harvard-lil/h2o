# via: https://github.com/harvard-lil/h2o/blob/c1726f0e038f325745139c46e0b552a20e4bf9c3/lib/html_helpers.rb

module HTMLFormatter
  class V3 < V2
    EFFECTIVE_DATE = Date.new(2018, 10, 10)
    class << self
      def unwrap! html
        html
          .xpath('//article | //section | //aside')
          .each { |el| el.replace el.children }
        html
      end
    end
  end

  @@versions << V3
end
