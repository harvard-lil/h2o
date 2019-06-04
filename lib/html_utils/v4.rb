# via: https://github.com/harvard-lil/h2o/blob/9626cb48f412e56f5f4d2b99d25945d645208fd2/lib/html_helpers.rb

module HTMLUtils
  class V4 < V3
    EFFECTIVE_DATE = Date.new(2019, 4, 15)
    class << self
      def unwrap! html
        html
          .xpath('//article | //section')
          .each { |el| el.replace el.children }
        html
      end
    end
  end

  @@versions << V4
end
