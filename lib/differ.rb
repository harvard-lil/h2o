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

        # the last-processed diff_with_range, if any
        previous = diffs_with_ranges.last

        # For use in calculating the "before..range" of this diff:
        #
        # If the last diff was an insertion, the current diff began
        # in the same spot the last one did: the start of the "before..range".
        # Otherwise, the current diff began after the last diff finished:
        # the end of the "before...range".
        start_before = previous&.[](0) == :insert ?
                         previous[2].min :
                         previous&.[](2)&.max || 0

        # For use in calculating the "after..range" of this diff:
        #
        # If the last diff was a deletion, the current diff will start
        # exactly where the deletion did: the start of the "after..range".
        # Otherwise, the current diff will start after the last diff finishes:
        # the end of the "after...range".
        start_after = previous&.[](0) == :delete ?
                        previous[3].min :
                        previous&.[](3)&.max || 0

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

    # test whether the offset is negative or greater than the text from which the diffs were generated
    def offset_out_of_bounds? diffs, offset
      offset < 0 || diffs.last[2].max < offset
    end

    def get_delta_at_offset diffs, offset
      return 0 if offset_out_of_bounds?(diffs, offset)

      # Reverse the list so we find the last diff that includes the offset and for which the offset isn't at the start of the diff (i.e. before the changes in that diff would have any effect)
      diff = diffs.reverse.find { |diff|
        diff[2].max >= offset && diff[2].min < offset
      }

      # if the last diff is a deletion, shift the offset backward to the beginning of the deletion,
      # otherwise get the difference between the before and after ranges
      diff[3].min - (diff[0] == :delete ? offset : diff[2].min)
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
