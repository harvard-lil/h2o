<script>
import { tupleToVNode } from "../libs/resource_section_parsing"

import ResourceSectionWrapper from "./ResourceSectionWrapper";
import SpacePreserver from "./SpacePreserver";
import ElisionAnnotation from "./ElisionAnnotation";
import ReplacementAnnotation from "./ReplacementAnnotation";
import HighlightAnnotation from "./HighlightAnnotation";
import LinkAnnotation from "./LinkAnnotation";
import NoteAnnotation from "./NoteAnnotation";
import FootnoteLink from "./FootnoteLink";

export default {
  components: {
    ResourceSectionWrapper,
    SpacePreserver,
    ElisionAnnotation,
    ReplacementAnnotation,
    HighlightAnnotation,
    LinkAnnotation,
    NoteAnnotation,
    FootnoteLink
  },
  props: {
    tuple: {type: Array,
            required: true},
    index: {type: Number,
            required: true}
  },
  render(h) {
    return h("resource-section-wrapper",
             {props: {tuple: this.tuple,
                      index: this.index}},
             [tupleToVNode(h, this.index)(this.tuple)]);
  }
};
</script>
