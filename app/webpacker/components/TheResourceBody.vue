<script>
import { unwrapUndesiredTags,
         emptyULToP,
         wrapBareInlineTags,
         removeEmptyNodes } from "../libs/html_helpers";

import { transformToTuplesWithOffsets,
         tupleToVNode } from "../libs/resource_node_parsing"

import SpacePreserver from "./SpacePreserver";
import ElisionAnnotation from "./ElisionAnnotation";
import ReplacementAnnotation from "./ReplacementAnnotation";
import HighlightAnnotation from "./HighlightAnnotation";
import LinkAnnotation from "./LinkAnnotation";
import NoteAnnotation from "./NoteAnnotation";
import FootnoteLink from "./FootnoteLink";

export default {
  components: {
    SpacePreserver,
    ElisionAnnotation,
    ReplacementAnnotation,
    HighlightAnnotation,
    LinkAnnotation,
    NoteAnnotation,
    FootnoteLink
  },
  props: {
    resource: {type: Object}
  },
  computed: {
    sections() {
      const parser = new DOMParser();
      let doc = parser.parseFromString(this.resource.content, "text/html");
      
      // Some resources are pure text without a wrapping HTML doc.
      // In this case, body.children will return an empty array.
      // Wrap that text in a div so that render() can expect HTMLElements
      if(doc.body.children.length == 0) {
        let div = document.createElement("div");
        div.appendChild(document.createTextNode(this.resource.content));
        return [div];
      } else {
        unwrapUndesiredTags(doc);
        emptyULToP(doc);
        wrapBareInlineTags(doc);
        removeEmptyNodes(doc);
        return Array.from(doc.body.children);
      }
    },
  },
  render(h) {
    return h("DIV",
             {class: "case-text"},
             this.sections
               .reduce(transformToTuplesWithOffsets(0), [])
               .map((tuple) => tupleToVNode(h, this.$store.state.annotations.all)(tuple)));
  }
};
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.case-text {
  counter-reset: index;
  @include serif-text($regular, 18px, 31px);
  /* hacks for misbehaving blockquotes */
  blockquote {
    span p {
      display: inline; // yes, p in span is illegal, but we have them
    }
  }
  /* section numbers */
  > * {
    position: relative;
    &::before {
      counter-increment: index;
      content: counter(index);
      user-select: none;
      @include sans-serif($regular, 12px, 12px);

      /* these two styles, coupled with position: relative on the parent,
       enable page numbers to be hidden when the full paragraph is elided */
      overflow: hidden;
      height: 100%;

      position: absolute;
      width: 100px;
      left: -145px;
      text-align: right;

      line-height: 30px;
      color: $light-blue;
    }
  }
}
.page-number {
  font-size: small;
  color: darkgrey;
  vertical-align: super;
  margin: 4px;
}
.footnote {
  a {
    float: left;
    margin-top: -8px;
	font-size: 16px;
  }

  p, blockquote {
    margin-left: 13px;
  }
}
.footnotemark {
  font-size: 16px;
  vertical-align: super;
}
/*
 * These use /deep/ to influence HighlightAnnotation.
 * They must live here so that they can change in relation to
 * their parent element.
 */
p /deep/ {
  .highlight .selected-text,
  .replacement .selected-text,
  .replacement .replacement-text {
    padding: 0.35em 0;
  }
}
h2 /deep/ {
  .highlight .selected-text,
  .replacement .selected-text,
  .replacement .replacement-text {
    padding: 0.05em 0;
  }
}
</style>
