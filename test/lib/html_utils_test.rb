# coding: utf-8
require 'test_helper'

class HTMLUtilsTest < ActiveSupport::TestCase
  describe HTMLUtils, :cleanse do
    it "should remove comment nodes from HTML" do
      comments = "<!-- foo --><!-- bar -->"
      html = "#{comments}<div>foobar</div>"
      assert_equal html.sub(comments, ""), HTMLUtils.cleanse(html)
    end

    it "should pull content out of specific tags and place it at the parent level" do
      ["article",
       "section"].each do |tag|
        after = "<p>foobar</p>"
        before = "<#{tag}>#{after}</#{tag}>"
        assert_equal after, HTMLUtils.cleanse(before)
      end
    end

    it "should find ul elements with text but no li's and convert them to p's" do
      before = "<ul>foobar</ul>"
      after = "<p>foobar</p>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    it "should find inline elements at the top level and wrap them in a paragraph" do
      before = "<span>foobar</span>"
      after = "<p>#{before}</p>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    it "should not wrap block level elements" do
      html = "<div>foobar</div>"
      assert_equal html, HTMLUtils.cleanse(html)
    end

    it "should remove whitespace between top level nodes" do
      before = "<div>foo</div>  \n  \n<div>bar</div>  \n  \n"
      after = "<div>foo</div><div>bar</div>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    #
    # For our information
    #

    it "removes (most) whitespace at the beginning of (most) text nodes" do
      # not children of <pre>; possibly others
      before = "<div>\n  hi</div>"
      after = "<div>hi</div>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    it "does not remove non-breaking spaces from the beginnng of text nodes" do
      html = "<div>&nbsp;hi</div>"
      assert_equal html, HTMLUtils.cleanse(html)
    end

    it "condenses repeated whitespace within text nodes" do
      before = "<p>hi\n    there</p>"
      after = "<p>hi there</p>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    # if vertical_space: 'no'
    it "adds a newline after <br> tags" do
      # ... but we'd prefer if it didn't
      before = "<div>foo<br>\nbar</div>"
      after = "<div>foo<br>\nbar</div>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    # if vertical_space: 'no'
    it "adds newlines inside block-level tags" do
      # ... but we'd prefer if it didn't.
      # Certain block-level tags get special treatment (article, section, pre)
      ["blockquote", "footer", "nav", "main",
       "figure", "center"].each do |tag|
        before = "<#{tag}><p>hi</p></#{tag}>"
        after = "<#{tag}>\n<p>hi</p>\n</#{tag}>"
        assert_equal after, HTMLUtils.cleanse(before)
      end
    end

    # if vertical_space: 'auto'
    # it "removes newlines that separate  block-level tags" do
    #   # ... but we'd probably prefer if it didn't.
    #   # Certain block-level tags get special treatment (article, section, pre)
    #   ["blockquote", "footer", "nav", "main",
    #    "figure", "center"].each do |tag|
    #     before = "<#{tag}>\n<p>hi</p>\n</#{tag}>"
    #     after = "<#{tag}><p>hi</p></#{tag}>"
    #     assert_equal after, HTMLUtils.cleanse(before)
    #   end
    # end

    it "handles unicode with high codepoints" do
      # Srinivasa Ramanujan Iyengar (1887–1920)
      html = "<div>ஸ்றீனிவாஸ ராமானுஜன் ஐயங்கார் ⊺ ∰</div>"
      assert_equal html, HTMLUtils.cleanse(html)
    end

    it "replaces HTML special chars to with HTML char entities" do
      before = '<div>&<"</div>'
      after = '<div>&amp;&lt;"</div>'
      assert_equal after, HTMLUtils.cleanse(before)
    end

    it "replaces HTML char entities with UTF-8 encoded chars" do
      before = "<div>&shy;&copy;&#39;&#169;</div>"
      # NB: the soft hyphen is present, but may not display in your editor
      after = "<div>­©'©</div>"
      assert_equal after, HTMLUtils.cleanse(before)
    end

    it "strips dangerous tags and properties" do
      before = "<div onClick=\"alert('bar')\">foo <script>alert('bar');</script></div>"
      after = "<div>foo \n</div>" # the extra newline here is inserted by tidy-html; consider running sanitize before tidy
      assert_equal after, HTMLUtils.cleanse(before)
    end
  end
end
