module HTMLHelpers
  class << self
    def strip_comments! html
      html.xpath('//comment()').remove
      html
    end

    def unnest! html
      html
        .xpath('//div | //article | //section | //aside')
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
        .xpath('//body/*[not(self::p|self::center|self::blockquote|self::article)]')
        .each { |inline_element| inline_element.replace "<p>#{inline_element.to_html}</p>" }
      html
    end

    def get_body_nodes_without_whitespace_text html
      html.xpath "//body/node()[not(self::text()) and not(self::text()[1])]"
    end

    def filter_empty_nodes nodes
      nodes.select { |node| node&.content&.present? }
    end

    def process_p_nodes html
      [:strip_comments!,
       :unnest!,
       :empty_ul_to_p!,
       :wrap_bare_inline_tags!,
       :get_body_nodes_without_whitespace_text,
       :filter_empty_nodes].reduce(html) { |memo, fn| send(fn, memo) }
    end
  end
end
