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
    childTuples: {type: Array},
    index: {type: Number},
    enclosingAnnotationIds: {type: Array,
                             default: (() => [])},
    startOffset: {type: Number,
                  default: 0}
  },
  computed: {
    _childTuples() {
      return this.childTuples ||
        Array.from(this.el.childNodes)
      // remove anything that isn't Element or an Text
      // i.e. no script or comment tags etc
        .filter(this.isValidNodeType)
      // transform our Node array to an array of [Node, startOffset, endOffset] tuples
        .reduce(this.transformToTuplesWithOffsets, [])
      // break next nodes at points where annotations exist
        .reduce((tuples, tuple) => tuples.concat(
          this.isText(tuple[0])
            ? this.splitTextAtBreakpoints(tuple)
            : [tuple]
        ), []);
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
    ...mapGetters(["getBySectionIndexSpan",
                   "getBySectionIndexStartingAt",
                   "getBySectionIndexFullSpan",
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
    },
    groupIntoAnnotation(h, prevEnd, tuples){
      return (prevTuple, annotation) => {
        // Figure out how far to reach forward for
        // elements to group into this annotation.
        // If the annotation ends in a subsequent
        // pararaph, use the max offset of the parent element
        let annotationEndInSection = annotation.end_paragraph == this.index ? annotation.end_offset : this.endOffset;
        // get the forward elements that fall within our range
        let childTuples = [prevTuple, ...tuples.filter(t => t[1] >= prevTuple[2] && t[2] <= annotationEndInSection)];
        let endOffset = childTuples[childTuples.length - 1][2];
        return [
          h(this.kindToComponent(annotation.kind),
            {props: {annotation: annotation,
                     startOffset: prevEnd,
                     endOffset: endOffset}},
            [h("resource-element",
               {props: {el: document.createElement("span"),
                        childTuples: childTuples,
                        index: this.index,
                        enclosingAnnotationIds: this.enclosingAnnotationIds.concat(annotation.id),
                        startOffset: prevEnd,
                        endOffset: endOffset}})]),
          prevEnd,
          endOffset
        ]
      }
    }
  },
  render(h) {
    return h(this.el.tagName,
             {attrs: this.attrs},
             this._childTuples
             .reduce((tuples, tuple, idx, src) => {
               let [node, startOffset, endOffset] = tuple;
               let [prevNode, prevStart, prevEnd] = tuples[tuples.length - 1] ||
                   [null, null, this.startOffset];
               // if this node has already been grouped into an
               // annotation's children list, skip it in the tuples
               if(prevEnd > startOffset) return tuples;

               return tuples.concat([
                 this.getBySectionIndexFullSpan(this.$store)(this.index, startOffset, endOffset)
                   .filter(a => this.enclosingAnnotationIds.indexOf(a.id) == -1)
                   .slice(0, 1)
                   .reduce(this.groupIntoAnnotation(h, prevEnd, src), tuple)]);
             }, [])
             .map(([node, startOffset, endOffset]) => {
               if(this.isText(node)) {
                 return node.textContent;
               } else if(this.isElement(node)) {
                 // For Element nodes, recursively call ResourceElement
                 // to loop back through this process
                 return h("resource-element",
                          {props: {el: node,
                                   index: this.index,
                                   startOffset: startOffset,
                                   endOffset: endOffset}});
               } else {
                 return node;
               }
             }));
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
