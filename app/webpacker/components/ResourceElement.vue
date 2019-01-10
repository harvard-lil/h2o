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
    children: {type: Array},
    index: {type: Number},
    startOffset: {type: Number,
                  default: 0}
  },
  computed: {
    _children() {
      return this.children || Array.from(this.el.childNodes);
    },
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
    isValidNodeType(node){
      return this.isElement(node) || this.isText(node)
    },
    transformToTuplesWithOffsets(tuples, node){
      let [prevNode, prevStart, prevEnd] = tuples[tuples.length - 1] ||
          [null, null, this.startOffset];
      return tuples.concat([[node, prevEnd, prevEnd + this.getLength(node)]]);
    },
    splitTextAtBreakpoints([node, startOffset, endOffset]) {
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
    return h(this.el.tagName,
             {attrs: this.attrs},
             this._children
             // remove anything that isn't Element or an Text
             // i.e. no script or comment tags etc
             .filter(this.isValidNodeType)
             // transform our Node array to an array of [Node, startOffset, endOffset] tuples
             .reduce(this.transformToTuplesWithOffsets, [])
             .reduce((tuples, tuple) => tuples.concat(
               this.isText(tuple[0])
                 ? this.splitTextAtBreakpoints(tuple)
                 : [tuple]
             ), [])
             .map(([node, startOffset, endOffset]) =>
                  // maybe start looking ahead here, then checking on
                  // the endOffset of the previous loop to see how
                  // much it vacuumed up
                  this.isText(node) ?
                  // Wrap Text nodes in any annotations since Vue limits us from
                  // recursively creating ResourceElements with Text nodes
                  this.getBySectionIndexFullSpan(this.$store)(this.index, startOffset, endOffset)
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
