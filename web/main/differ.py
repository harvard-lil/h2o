from bisect import bisect_right
from diff_match_patch import diff_match_patch

from .utils import re_split_offsets


def assert_offsets_adjusted(before_str, after_str):
    """
         This is a test helper for visually testing the AnnotationUpdater.adjust_offset() function. Example:

         >>> assert_offsets_adjusted("f*oo b*ar b*uzz", "f*oo *b*uzz")

         This models an update from "foo bar buzz" to "foo buzz", treating each * as an annotation, and ensures that the
         stars in the first string are adjusted so that they end up in the specified place in the second string.
    """
    # calculate adjusted offsets
    _, offsets, _ = re_split_offsets(r'\*', before_str)
    updater = AnnotationUpdater(before_str.replace("*", ""), after_str.replace("*", ""))
    adjusted_offsets = [updater.adjust_offset(i) for i in offsets]

    # re-insert annotations into after_str using adjusted offsets
    adjusted_str = after_str.replace("*", "")
    for offset in reversed(adjusted_offsets):
        adjusted_str = adjusted_str[:offset] + "*" + adjusted_str[offset:]

    # verify correct results
    assert adjusted_str == after_str, f"{before_str} was adjusted to {adjusted_str}, not {after_str}"


class AbsoluteDelta(int):
    def apply_delta(self, offset):
        return self


class RelativeDelta(int):
    def apply_delta(self, offset):
        return self + offset


class AnnotationUpdater:
    def __init__(self, before, after):
        """
            This function calculates, for each character in `before`, what delta should be applied to annotations
            for that character so it ends up in the same location in `after`. The results are stored in self.offsets
            and self.deltas, which are same-size lists kept separate for bisect_right lookups later.

            For example, suppose we have:

                before: "Kids happily eat their meals."
                after:  "Kids eat their happy meals."

            We need to apply the following deltas to each offset in `before`:

                 Kids happily eat their meals.
                 |----|-------|---------|-----
                 +0   =5      -8        -2
                 |----|---------......|-----
                 Kids eat their happy meals.

            Note that offsets in the preserved words need to be shifted + or -, but annotations in "happily"
            need to be set equal to 5 because the word was deleted.

            This gets stored as:

            >>> a = AnnotationUpdater("Kids happily eat their meals.", "Kids eat their happy meals.")
            >>> assert a.offsets == [0, 5, 13, 23]  # the offset beginning each range in the first string
            >>> assert a.deltas == [RelativeDelta(0), AbsoluteDelta(5), RelativeDelta(-8), RelativeDelta(-2)]
        """
        if before == after:
            raise ValueError("AnnotationUpdater requires that strings have changed.")

        offset = 0
        delta = 0
        self.offsets = offsets = []
        self.deltas = deltas = []
        self.max_offset = len(before)

        for op, text in self.get_dmp_diff(before, after):
            if op == diff_match_patch.DIFF_EQUAL:
                # for "equal", start a new range with a relative delta, and push the offset forward
                offsets.append(offset)
                deltas.append(RelativeDelta(delta))
                offset += len(text)
            elif op == diff_match_patch.DIFF_INSERT:
                # for "insert", just push the delta forward
                delta += len(text)
            else:  # op == diff_match_patch.DIFF_DELETE
                # for "delete", start a new range with an absolute delta. push the offset forward and delta backward.
                offsets.append(offset)
                deltas.append(AbsoluteDelta(offset+delta))
                offset += len(text)
                delta -= len(text)

    @staticmethod
    def get_dmp_diff(before, after):
        """
            Get diff from the diff-match-patch library:

            >>> assert AnnotationUpdater.get_dmp_diff("Kids happily eat their meals.", "Kids eat their happy meals.") == [
            ...     (diff_match_patch.DIFF_EQUAL, "Kids "),
            ...     (diff_match_patch.DIFF_DELETE, "happily "),
            ...     (diff_match_patch.DIFF_EQUAL, "eat their "),
            ...     (diff_match_patch.DIFF_INSERT, "happy "),
            ...     (diff_match_patch.DIFF_EQUAL, "meals."),
            ... ]
        """
        dmp = diff_match_patch()
        diffs = dmp.diff_main(before, after)
        dmp.diff_cleanupSemantic(diffs)
        return diffs

    def get_first_delta_offset(self):
        """
            Return offset of first non-equal operation. Annotations before this point can be left as-is:
            >>> assert AnnotationUpdater("foo bar", "foo Bar").get_first_delta_offset() == 4
            >>> assert AnnotationUpdater("foo bar", "bar").get_first_delta_offset() == 0
        """
        # find the offset of either the first absolute delta, or the first relative delta with a non-0 value
        return next((offset for offset, delta in zip(self.offsets, self.deltas) if type(delta) is AbsoluteDelta or delta != 0), -1)

    def adjust_offset(self, offset):
        """
            Apply appropriate delta for the given offset:

            >>> assert_offsets_adjusted("fo*o b*uzz", "fo*o bar b*uzz")  # adding word
            >>> assert_offsets_adjusted("fo*o b*ar b*uzz", "fo*o *b*uzz")  # deleting word
            >>> assert_offsets_adjusted("fo*o l*orem b*uzz", "fo*o *ipsum b*uzz")  # editing word
            >>> assert_offsets_adjusted("*ba*r b*uzz*", "foo *ba*r b*uzz* bazz")  # prepending/appending word
            >>> assert_offsets_adjusted("fo*o ba*r b*uzz b*azz", "*ba*r b*uzz*")  # un-prepending word
            >>> assert_offsets_adjusted("fo*o ip*sum b*ar b*uzz", "fo*o lorem ip*sum *b*uzz")  # inserting and then deleting word

            TODO: Treatment of inserts right next to annotations is pretty arbitrary,
            because of the best-effort output of diff_cleanupSemantic to make readable diffs.
            It would be possible to distinguish between start and end annotations, and always have inserts
            go inside or outside if one is preferable.
            >>> assert_offsets_adjusted("foo *bar* baz", "foo *buzz* baz")
            >>> assert_offsets_adjusted("foo *bar* baz", "foo *lorem bar ipsum* baz")
            >>> assert_offsets_adjusted("foo *bar* baz", "foo *bar* ipsum baz")  # ipsum is outside, unlike previous example, because of diff cleanup
            >>> assert_offsets_adjusted("foo *bar* baz", "foo re*barbosa* baz")  # one goes inside and one outside

            Handling of offsets at or beyond the right edge:
            >>> assert_offsets_adjusted("foo*", "foo* bar")
            >>> assert AnnotationUpdater("foo", "foo bar").adjust_offset(10) == 3
            >>> assert_offsets_adjusted("foo bar*", "foo *lorem")
        """
        offset = min(self.max_offset, offset)  # clamp offsets to the end of the original text
        return self.deltas[bisect_right(self.offsets, offset)-1].apply_delta(offset)
