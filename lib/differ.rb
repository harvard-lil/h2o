module Differ
  class << self
    def get_dmp_diffs before, after
      dmp = DiffMatchPatch.new
      # https://github.com/google/diff-match-patch/wiki/API#diff_maintext1-text2--diffs
      diffs = dmp.diff_main(before, after)
      # https://github.com/google/diff-match-patch/wiki/API#diff_cleanupsemanticdiffs--null
      dmp.diff_cleanupSemantic(diffs)
      diffs
    end

    def calculate_ranges dmp_diffs
      dmp_diffs.reduce([]) do |diffs_with_ranges, diff|
        start_before = diffs_with_ranges.last&.[](0) == :insert ?
                         diffs_with_ranges.last[2].min :
                         diffs_with_ranges.last&.[](2)&.max || 0

        start_after = diffs_with_ranges.last&.[](0) == :delete ?
                        diffs_with_ranges.last[3].min :
                        diffs_with_ranges.last&.[](3)&.max || 0

        diffs_with_ranges + [diff + [start_before..start_before + diff[1].length,
                                     start_after..start_after + diff[1].length]]
      end
    end

    # return structure:
    # [:action, "affected string", (before..range), (after..range)]
    def get_diffs before, after
      calculate_ranges(get_dmp_diffs(before, after))
    end

    def get_first_delta_offset diffs
      diffs.find { |diff| diff[0] != :equal }&.[](2)&.min || -1
    end

    def range_was_deleted? diffs, range
      !!diffs.find { |diff|
        diff[0] == :delete &&
          diff[2].min <= range.min &&
          diff[2].max >= range.max
      }
    end

    def get_delta_at_offset diffs, offset
      # reverse the list so we find the last diff
      # that includes this offset
      diffs.reverse.find { |diff|
        diff[2].include?(offset)
      }[2..3].map(&:min).reverse.reduce(:-)
    end

    def adjust_offset diffs, offset
      offset + get_delta_at_offset(diffs, offset)
    end

    def adjust_range diffs, range
      range_was_deleted?(diffs, range) ?
        (-1..-1) :
        (adjust_offset(diffs, range.min)..adjust_offset(diffs, range.max))
    end
  end
end
