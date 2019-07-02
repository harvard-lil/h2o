require 'test_helper'

class DifferTest < ActiveSupport::TestCase
  describe Differ, :get_diffs do
    it "should return an array of diffs with the format [:action, \"affected string\", (before..range), (after..range)]" do
      diffs = Differ.get_diffs "foo bar buzz", "foo BAR buzz"
      assert_equal [[:equal,  "foo ",  0..4, 0..4],
                    [:delete, "bar",   4..7, 4..7],
                    [:insert, "BAR",   7..10, 4..7],
                    [:equal,  " buzz", 7..12, 7..12]],
                   diffs
    end

    it "should ignore coincidental matches" do
      before = "abc def ghij"
      after = "kl mnop qrstuvw xyz"
      diffs = Differ.get_diffs(before, after)
      assert_equal [[:delete, before], [:insert, after]],
                   diffs.map { |d| d[0..1] }
    end
  end

  describe Differ, :get_first_delta_offset do
    it "should return the offset of the first diff that modifies the content (i.e. not :equal)" do
      diffs = Differ.get_diffs("foo bar", "foo Bar")
      assert_equal 4, Differ.get_first_delta_offset(diffs)
    end
  end

  describe Differ, :get_delta_at_offset do
    it "should return the difference between the original number of characters preceeding this offset and the new number of characters preceeding it" do
      diffs = Differ.get_diffs("foo ipsum", "foo bar lorum ipsum")
      assert_equal 10, Differ.get_delta_at_offset(diffs, 5)
    end

    it "should return correct number of characters deleted preceeding offset when last diff is a deletion" do
      diffs = Differ.get_diffs("foo bar lorum ipsum", "foo bar ipsum")
      assert_equal -3, Differ.get_delta_at_offset(diffs, 11)
    end

    it "should handle deletions immediately followed by insertions" do
      diffs = Differ.get_diffs("foo bar lorum ipsum", "foo super lorum ipsum")
      assert_equal 2, Differ.get_delta_at_offset(diffs, 11)
    end

    it "ignore changes that come after the supplied offset" do
      diffs = Differ.get_diffs("foobar", "foo bar")
      assert_equal 0, Differ.get_delta_at_offset(diffs, 3)
    end
  end

  describe Differ, :range_was_deleted? do
    it "should return true if the specified range was a subset of a deleted range of text" do
      diffs = Differ.get_diffs("foo bar buzz", "foo buzz")
      assert Differ.range_was_deleted? diffs, 5..6
    end

    it "should return true if the specified range was the exact range of a deleted range of text" do
      diffs = Differ.get_diffs("foo bar buzz", "foo buzz")
      assert Differ.range_was_deleted? diffs, 4..7
    end

    it "should return false if any part of the specified range was not part of a deleted range of text" do
      diffs = Differ.get_diffs("foo bar buzz", "foo buzz")
      refute Differ.range_was_deleted? diffs, 4..9
    end
  end

  describe Differ, :adjust_offset do
    it "should shift offset forward when text is prepended" do
      before = "this is the text"
      after = "and this is the text"
      offset = 10
      delta = after.length - before.length
      diffs = Differ.get_diffs(before, after)
      assert_equal offset + delta, Differ.adjust_offset(diffs, offset)
    end

    it "should shift offset backward when text is removed from beginning" do
      before = "this is the text"
      after = "is the text"
      offset = 10
      delta = after.length - before.length
      diffs = Differ.get_diffs(before, after)
      assert_equal offset + delta, Differ.adjust_offset(diffs, offset)
    end

    it "should shift offset backward when text is removed from end" do
      before = "this is the text"
      after = "this is the"
      offset = 14
      diffs = Differ.get_diffs(before, after)
      assert_equal after.length, Differ.adjust_offset(diffs, offset)
    end

    it "should return identical offset when text is identical" do
      text = "this is the text"
      offset = 10
      diffs = Differ.get_diffs(text, text)
      assert_equal offset, Differ.adjust_offset(diffs, offset)
    end

    it "should not extend offset when text inserted after offset" do
      diffs = Differ.get_diffs("foobar", "foo bar")
      offset = 3
      assert_equal offset, Differ.adjust_offset(diffs, offset)
    end

    it "should deal with spaces after word deletion" do
      skip "we may or may not want this"
    end
  end

  describe Differ, :adjust_range do
    it "should adjust both the start and end of the range" do
      before = "this is the text"
      after = "and this is the text"
      range = 8..11
      delta = after.length - before.length
      diffs = Differ.get_diffs(before, after)
      assert_equal range.min + delta..range.max + delta,
                   Differ.adjust_range(diffs, range)
    end

    it "should return a negative range for a range that is deleted" do
      diffs = Differ.get_diffs("delete that word", "delete word")
      assert_equal -1..-1, Differ.adjust_range(diffs, 7..11)
    end
  end
end
