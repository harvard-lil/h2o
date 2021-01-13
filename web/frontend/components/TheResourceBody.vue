<script>
import { nodeToTuple,
         tupleToVNode } from "../libs/resource_node_parsing"
import _ from "lodash";

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
    body() {
      let node = new DOMParser().parseFromString(this.resource.content, "text/html").body;
      node.setAttribute("is", "DIV");
      node.setAttribute("class", "case-text");
      return node;
    }
  },
  render(h) {
    let annotations = this.$store.state.annotations.all;
    annotations.forEach(x => x.used = false);
    return tupleToVNode(h, annotations)(nodeToTuple(this.body));
  }
};
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.case-text {
    position: relative;
    counter-reset: index;
    @include serif-text($regular, 18px, 31px);

    /* hacks for misbehaving blockquotes */
    blockquote {
        span p {
            display: inline; /* yes, p in span is illegal, but we have them */
        }
    }
    /* paragraph numbers -- section.casebody handles HTML received from CAP */
    > :not(section), > section.casebody h4, > section.casebody p, > section.casebody blockquote {
        position: relative;
        &:not(.elision):not(.fully-elided) {
            &::before {
                content: counter(index);
                user-select: none;
                @include sans-serif($regular, 12px, 12px);
                position: fixed;
                width: 100px;
                left: -92px;
                text-align: right;
                line-height: 30px;
                color: $light-blue;
            }
        }
        counter-increment: index;
    }
    blockquote.fully-elided {
        padding:0px;
    }
    pre.fully-elided {
        padding:0;
        margin:0;
        border:none;
    }
    p.fully-elided {
        margin:0;
    }
    pre {
        overflow: initial;
        word-break: break-word;
        overflow-wrap: break-word;
        white-space: pre-wrap;
    }
  h2 {
    @include serif-text($regular, 20px, 24px);
  }
}
.page-number, .page-label {
  font-size: small;
  color: darkgrey;
  vertical-align: super;
  margin: 4px;
}

// no margin between consecutive blockquotes, only at the end
blockquote {
  margin: 0;
}
blockquote + :not(blockquote) {
  margin-top: 20px;
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
p ::v-deep {
  .highlight .selected-text,
  .replacement .selected-text,
  .replacement .replacement-text {
    padding: 0.35em 0;
  }
}
h2 ::v-deep {
  .highlight .selected-text,
  .replacement .selected-text,
  .replacement .replacement-text {
    padding: 0.05em 0;
  }
}
</style>
