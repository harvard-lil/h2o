<script>
import { getLength } from "../libs/html_helpers";
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
    el: {type: HTMLElement,
         required: true},
    index: {type: Number,
            required: true}
  },
  render(h) {
    return h("resource-section-wrapper",
             {props: {index: this.index,
                      length: getLength(this.el)}},
             [tupleToVNode(h, this.index)([this.el, 0, getLength(this.el)])]);
  }
};
</script>
