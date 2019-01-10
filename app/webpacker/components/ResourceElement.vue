<script>
import { createNamespacedHelpers } from 'vuex';
const { mapGetters } = createNamespacedHelpers('annotations');

import ElisionAnnotation from "./ElisionAnnotation";
import ReplacementAnnotation from "./ReplacementAnnotation";
import HighlightAnnotation from "./HighlightAnnotation";
import LinkAnnotation from "./LinkAnnotation";
import NoteAnnotation from "./NoteAnnotation";

export default {
  name: "resource-element", // required for recursive use
  components: {
    ElisionAnnotation,
    ReplacementAnnotation,
    HighlightAnnotation,
    LinkAnnotation,
    NoteAnnotation
  },
  props: {
    el: {type: HTMLElement},
    index: {type: Number},
    startOffset: {type: Number,
                  default: 0}
  },
  computed: {
    endOffset() {
      return this.startOffset + (this.el.innerText || this.el.textContent).length;
    },
    fullSpanAnnotations() {
      return this.getBySectionIndexFullSpan(this.$store)(this.index, this.startOffset, this.endOffset);
    },
    partialSpanAnnotations() {
      return this.getBySectionIndexPartialSpan(this.$store)(this.index, this.startOffset, this.endOffset);
    },
    // Return the offsets within this element where
    // annotations need to start or end
    annotationBreakpoints() {
      return this.partialSpanAnnotations.reduce(
        (offsets, annotation) =>
          offsets.concat(
            ["start", "end"]
              .filter(s => annotation[`${s}_paragraph`] == this.index)
              .map(s => annotation[`${s}_offset`]))
        , [])
        .sort((a, b) => a - b); // sort lowest to highest
    },
    attrs() {
      let nodelist = this.el.attributes;
      let attrmap = {};
      let i = 0;
      for (; i < nodelist.length; i++) {
        attrmap[nodelist[i].name] = nodelist[i].value;
      }
      return attrmap;
    }
  },
  methods: {
    ...mapGetters(["getBySectionIndexFullSpan",
                   "getBySectionIndexPartialSpan"]),
    kindToComponent(kind) {
      return ({elide: "elision",
               replace: "replacement"}[kind] || kind) + "-annotation";
    },
    isElement: node => node.nodeType == 1,
    isText: node => node.nodeType == 3,
    getLength(node) {
      return (this.isElement(node) ? node.innerText : node.textContent).length;
    },
    wrapInAnnotation(h, startOffset, endOffset) {
      return (node, annotation) =>
        h(this.kindToComponent(annotation.kind),
          {props: {annotation: annotation,
                   startOffset: startOffset,
                   endOffset: endOffset}},
          [node])
    },
    splitTextNodeAtBreakpoints([node, startOffset, endOffset]) {
      return this.annotationBreakpoints
      // remove any offsets that fall on or outside of the Text node
        .filter(breakpoint =>
                breakpoint > startOffset &&
                breakpoint < endOffset)
      // split the Text node; splitText() mutates the existing node
      // in our array, truncating it, and returns a new node with
      // the remaining text
        .reduce((tuples, breakpoint) => {
          let [prevNode, prevStart, prevEnd] = tuples[tuples.length - 1];
          let node = prevNode.splitText(breakpoint - prevStart);
          tuples[tuples.length - 1][2] = breakpoint;
          return tuples.concat([[node, breakpoint, prevEnd]]);
        }, [[node, startOffset, endOffset]])
    }
  },
  render(h) {
    // get the child nodes of the HTMLElement
    // and make them an array we can filter and format
    return h(this.el.tagName,
             {attrs: this.attrs},
             Array.from(this.el.childNodes)
             // remove anything that isn't Element or an Text
             // i.e. no script or comment tags etc
             .filter(node => this.isElement(node) || this.isText(node))
             // transform our Node array to an array of [Node, offset] tuples
             .reduce((tuples, node) => {
               let [prevNode, prevStart, prevEnd] = tuples[tuples.length - 1] ||
                   [{textContent: ""}, this.startOffset, this.startOffset];
               let tuple = [node, prevEnd, prevEnd + this.getLength(node)];

               return tuples.concat(this.isText(node) ?
                                    this.splitTextNodeAtBreakpoints(tuple) :
                                    [tuple]);
             }, [])
             .map(([node, startOffset, endOffset]) =>
                  this.isText(node) ?
                  // Wrap Text nodes in any annotations since Vue limits us from
                  // recursively creating ResourceElements with Text nodes
                  this.getBySectionIndexFullSpan(this.$store)(this.index, startOffset, startOffset + node.textContent.length)
                  .reduce(this.wrapInAnnotation(h, startOffset, endOffset), node.textContent)
                  // For Element nodes, recursively call ResourceElement
                  // to loop back through this process
                  : h("resource-element",
                      {props: {el: node,
                               index: this.index,
                               startOffset: startOffset,
                               endOffset: endOffset}})));
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
