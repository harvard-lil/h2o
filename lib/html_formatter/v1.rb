# via: https://github.com/harvard-lil/h2o/blob/744989ba635dd90990c40e2cccac6febfe61ad21/app/models/content/resource.rb

module HTMLFormatter
  class V1
    EFFECTIVE_DATE = Date.new(1970)
    class << self
      def strip_comments! html
        html.xpath('//comment()').remove
        html
      end

      def unwrap! html
        html
          .xpath('//div')
          .each { |el| el.replace el.children }
        html
      end

      def empty_ul_to_p! html
        html
          .xpath('//body/ul[not(*[li])]')
          .each { |list| list.replace "<p>#{list.inner_html}</p>" }
        html
      end

      def wrap_bare_inline_tags! html
        html
          .xpath("//body/*[not(self::p|self::center|self::blockquote|self::article)]")
          .each { |el| el.wrap "<p>" }
        html
      end

      def get_body_nodes_without_whitespace_text html
        html.xpath "//body/node()[not(self::text()) and not(self::text()[1])]"
      end

      def filter_empty_nodes! nodes
        nodes.each do |node|
          if ! node.nil? && node.children.empty?
            nodes.delete(node)
          end
        end
        nodes
      end

      def pipeline
        [
          method(:parse),
          method(:strip_comments!),
          method(:unwrap!),
          method(:empty_ul_to_p!),
          method(:wrap_bare_inline_tags!),
          method(:get_body_nodes_without_whitespace_text),
          method(:filter_empty_nodes!),
          method(:to_html)
        ]
      end

      def parse html
        Nokogiri::HTML(html) { |config| config.strict.noblanks }
      end

      def to_html nodes
        # save_with: 0 avoids the addition of pretty-printing whitespace
        nodes.to_html(save_with: 0)
      end

      def process html_string
        pipeline.reduce(html_string) { |memo, fn| fn.call(memo) }
      end
    end
  end

  @@versions << V1
end
