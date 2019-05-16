require 'test_helper'

class HTMLHelpersTest < ActiveSupport::TestCase
  describe HTMLHelpers, :strip_comments! do
    it "should remove comment nodes from HTML" do
      comments = "<!-- foo --><!-- bar -->"
      html_str = html_doc_str "#{comments}<div>foobar</div>"
      html = Nokogiri::HTML(html_str)
      assert_equal html_str.sub(comments, ""), HTMLHelpers.strip_comments!(html).to_s
    end
  end

  describe HTMLHelpers, :unnest! do
    it "should pull content out of specific tags and place it at the parent level" do
      ["article",
       "section"].each do |tag|
        before = html_doc_str "<#{tag}>foobar</#{tag}>"
        after = html_doc_str "foobar"
        assert_equal after, HTMLHelpers.unnest!(Nokogiri::HTML(before)).to_s
      end
    end
  end

  describe HTMLHelpers, :empty_ul_to_p! do
    it "should find ul elements with text but no li's and convert them to p's" do
      before = html_doc_str "<ul>foobar</ul>"
      after = html_doc_str "<p>foobar</p>"
      assert_equal after, HTMLHelpers.empty_ul_to_p!(Nokogiri::HTML(before)).to_s
    end
  end

  describe HTMLHelpers, :wrap_bare_inline_tags! do
    it "should find inline elements at the top level and wrap them in a paragraph" do
      tag = "<span>foobar</span>"
      before = html_doc_str tag
      after = html_doc_str "<p>#{tag}</p>"
      assert_equal after, HTMLHelpers.wrap_bare_inline_tags!(Nokogiri::HTML(before)).to_s
    end

    it "should not wrap block level elements" do
      tag = "<div>foobar</div>"
      before = html_doc_str tag
      after = html_doc_str tag
      assert_equal after, HTMLHelpers.wrap_bare_inline_tags!(Nokogiri::HTML(before)).to_s
    end
  end

  describe HTMLHelpers, :get_body_nodes_without_whitespace_text do
    it "should get top-level nodes within the body, excluding stretches of whitespace" do
      tags = "<div>foo</div><div>bar</div>"
      before = "#{tags}    \n    \n"
      after = html_nodes tags

      assert_not_equal after.to_s, html_nodes(before).to_s
      assert_equal after.map(&:to_s).join("").strip,
                   HTMLHelpers.get_body_nodes_without_whitespace_text(
                     Nokogiri::HTML(before)).map(&:to_s).join("").strip
    end
  end

  def html_doc_str inner_html
    "<!DOCTYPE html>\n<html><body>\n#{inner_html}\n</body></html>\n"
  end

  def html_nodes str
    Nokogiri::HTML(html_doc_str(str)).xpath("//body/node()")
  end
end
