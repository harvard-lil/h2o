class RawContent < ApplicationRecord
  belongs_to :source, polymorphic: true

  def sanitized_content
    html = Tidy.exec(content)
    doc = Nokogiri::HTML(html)

    wrap_bare_inline_tags!(
      unnest!(doc)
    ).at('body').inner_html
  end

  private

  def unnest! html
    html
      .xpath('//article | //section | //aside')
      .each { |el| el.replace el.children }
    html
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
      .each { |el| el.wrap "<p>" }
    html
  end
end
