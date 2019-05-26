require 'test_helper'

class HTMLFormatterTest < ActiveSupport::TestCase
  describe HTMLFormatter, :process do
    it "should remove comment nodes from HTML" do
      comments = "<!-- foo --><!-- bar -->"
      html = "#{comments}<div>foobar</div>"
      assert_equal html.sub(comments, ""), HTMLFormatter.process(html)
    end

    it "should pull content out of specific tags and place it at the parent level" do
      ["article",
       "section"].each do |tag|
        after = "<p>foobar</p>"
        before = "<#{tag}>#{after}</#{tag}>"
        assert_equal after, HTMLFormatter.process(before)
      end
    end

    it "should find ul elements with text but no li's and convert them to p's" do
      before = "<ul>foobar</ul>"
      after = "<p>foobar</p>"
      assert_equal after, HTMLFormatter.process(before)
    end

    it "should find inline elements at the top level and wrap them in a paragraph" do
      before = "<span>foobar</span>"
      after = "<p>#{before}</p>"
      assert_equal after, HTMLFormatter.process(before)
    end

    it "should not wrap block level elements" do
      html = "<div>foobar</div>"
      assert_equal html, HTMLFormatter.process(html)
    end

    it "should remove whitespace between top level nodes" do
      before = "<div>foo</div>  \n  \n<div>bar</div>  \n  \n"
      after = "<div>foo</div><div>bar</div>"

      assert_equal after, HTMLFormatter.process(before)
    end
  end
end
