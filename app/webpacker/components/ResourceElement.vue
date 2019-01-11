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
                  default: 0},
    endOffset: {type: Number}
  },
  computed: {
    _endOffset() {
      return this.endOffset === undefined
        ? this.startOffset + this.getLength(this.el)
        : this.endOffset
    },

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

    // All of the annotations that start, end, or span over this section
    annotations() {
      return this.getBySectionIndex(this.$store)(this.index);
    },

    // Annotations whose start or end points fall WITHIN
    // (i.e. not on the edges)the bounds of this element.
    // Used for finding where to split Text nodes
    partialSpanAnnotations() {
      return this.annotations.filter(
        obj =>
          (obj.start_paragraph == this.index &&
           obj.start_offset > this.startOffset &&
           obj.start_offset < this._endOffset) ||
          (obj.end_paragraph == this.index &&
           obj.end_offset > this.startOffset &&
           obj.end_offset < this._endOffset))
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

    elAttrs() {
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

    /////////////////
    // Data access //
    /////////////////

    ...mapGetters(["getBySectionIndex"]),

    getAnnotationsAtOffset(offset) {
      return this.annotations.filter(
        obj =>
          (obj.start_paragraph < this.index || obj.start_offset <= offset) &&
          (obj.end_paragraph > this.index || obj.end_offset > offset)
      ).sort(
        // longest to shortest
        (a, b) =>
          (b.end_paragraph == this.index ? b.end_offset : Number.MAX_VALUE) -
          (a.end_paragraph == this.index ? a.end_offset : Number.MAX_VALUE));
    },

    /////////////
    // Helpers //
    /////////////

    kindToComponent(kind) {
      return ({elide: "elision",
               replace: "replacement"}[kind] || kind) + "-annotation";
    },
    
    isElement: node => node.nodeType == 1,
    
    isText: node => node.nodeType == 3,
    
    getLength(node) {
      return (this.isElement(node) ? node.innerText : node.textContent).length;
    },

    ///////////////////////////
    // Munging and filtering //
    ///////////////////////////

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

    // Loop through the tuples and add annotations when found
    insertAnnotations(h) {
      return (modifiedTuples, tuple, idx, orgTuples) => {
        let [node, startOffset, endOffset] = tuple;
        let [prevNode, prevStart, prevEnd] = modifiedTuples[modifiedTuples.length - 1] ||
            [null, null, this.startOffset];

        // if the previous tuple's end offset is greater than the current tuple's
        // start offset, the current tuple has already been grouped into an
        // annotation's children list so skip it in modifiedTuples so as not
        // to duplicate it in the render
        return prevEnd > startOffset
          ? modifiedTuples
          : modifiedTuples.concat([
            this.getAnnotationsAtOffset(startOffset)
              // Remove any annotations that have already been rendered upstream
              .filter(a => this.enclosingAnnotationIds.indexOf(a.id) == -1)
              // We only want the first annotation, for now, but keeping
              // it as an array conveniently allows reduce to
              // return the normal tuple as a default if no annotations exist
              .slice(0, 1)
              .reduce(this.groupIntoAnnotation(h, orgTuples), tuple)]);
      }
    },

    // Given an annotation and the previous tuple in the list, use the
    // annotation's offset information to move forward in the list,
    // eagerly grabbing tuples that fall within its range.
    // This is the logic that allows annotations to wrap around
    // existing elements on the page.
    groupIntoAnnotation(h, tuples){
      return (prevTuple, annotation) => {
        // Figure out how far to reach forward for elements to group into this annotation.
        // If the annotation extends beyond this section / pararaph,
        // use the end offset of this parent element
        let annotationEndInSection = annotation.end_paragraph == this.index ? annotation.end_offset : this._endOffset;
        // get the forward elements that fall within our range
        let childTuples = [prevTuple, ...tuples.filter(t => t[1] >= prevTuple[2] && t[2] <= annotationEndInSection)];
        let props = {startOffset: prevTuple[1],
                     endOffset: childTuples[childTuples.length - 1][2]};
        
        return [h(this.kindToComponent(annotation.kind),
                  {props: {...props,
                           annotation: annotation}},
                  [h("resource-element",
                     {props: {...props,
                              el: document.createElement("span"),
                              childTuples: childTuples,
                              index: this.index,
                              enclosingAnnotationIds: this.enclosingAnnotationIds.concat(annotation.id)}})]),
                props.startOffset,
                props.endOffset]
      }
    },

    // Vue component children arrays must contain either VNodes or
    // Strings (which get converted to VNodes automatically)
    tupleToVNode(h) {
      return ([node, startOffset, endOffset]) => {
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
      }
    }
  },
  render(h) {
    return h(this.el.tagName,
             {attrs: this.elAttrs},
             this._childTuples
               .reduce(this.insertAnnotations(h), [])
               .map(this.tupleToVNode(h)));
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
