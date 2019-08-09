# via: https://github.com/harvard-lil/h2o/blob/504b5e5d256c154ef50837b48fc69aa6956a9d91/lib/html_helpers.rb

module HTMLUtils
  class V7 < V6
    EFFECTIVE_DATE = Date.new(2019, 8, 9)
    class << self
      # Tidy notes:
      # in HTML 5 mode, Tidy doesn't add missing <ul> around bare <li> tags:
      # https://github.com/htacg/tidy-html5/issues/525
      # nor does it convert <ul> tags to <div> tags. In HTML 4 mode it does both of these things
      def tidy html_string
        Tidy.exec(html_string)
      end

      # Tidy won't wrap these when using the enclose-text flag since, though they are inline elements in some cases, they're block elements in others.
      # via: https://github.com/htacg/tidy-html5/blob/a71031f9e529f0aa74a819576411594e21767be4/src/tags.c
      CM_MIXED = ["a",
                  "del",
                  "ins",
                  "math",
                  "noscript",
                  "script",
                  "svg",
                  "nolayer",
                  "server",
                  "menuitem"]

      def wrap_bare_inline_tags! html
        html
          .xpath("//body/*[self::#{CM_MIXED.map(&:downcase).join('|self::')}]")
          .each { |el| el.replace "<p>#{el.to_html}</p>" }
        html
      end

      def pipeline
        [method(:tidy)] + super
      end
    end
  end

  @@versions << V7
end
