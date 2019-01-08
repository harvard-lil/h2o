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
    getText(node) {
      return this.isElement(node) ? node.innerText : node.textContent;
    }
  },
  render(h) {
    // get the child nodes of the HTMLElement
    // and make them an array we can filter and format
    let children = Array.from(this.el.childNodes)
        // remove anything that isn't Element or an Text
        // i.e. no script or comment tags etc
        .filter(node => this.isElement(node) || this.isText(node))
        .reduce((acc, node) => {
          let prev = acc[acc.length - 1] || [{textContent: ""}, this.startOffset];
          let startOffset = prev[1] + this.getText(prev[0]).length;

          let nodes = [[node, startOffset]];

          if(this.isText(node)) {
            return acc.concat(
              this.annotationBreakpoints
                .filter(n => n > startOffset &&
                            n < startOffset + node.textContent.length)
                .reduce((nodes, offset) =>
                        nodes.concat([[nodes[nodes.length - 1][0].splitText(offset - nodes[nodes.length - 1][1]), offset]]), nodes));
          } else {
            return acc.concat(nodes);
          }
        }, [])
        .map(([node, startOffset]) =>
             // if it's a text node, just return the text and
             // Vue will automatically turn it into a 'text VNode'
             this.isText(node) ?
             this.$store.getters['annotations/getBySectionIndexFullSpan'](this.index, startOffset, startOffset + node.textContent.length).reduce(
               (prev_node, annotation) =>
                 h(this.kindToComponent(annotation.kind),
                   {props: {annotationId: annotation.id}},
                   prev_node)
               , node.textContent)
             // else recursively call ResourceElement to loop back through this process
             : h("resource-element",
                 {props: {el: node,
                          index: this.index,
                          startOffset: startOffset}}));
    
    // Wrap the children in annotations if present
    children = this.fullSpanAnnotations
      .reduce((prev_el, annotation) =>
              [h(this.kindToComponent(annotation.kind),
                 {props: {annotationId: annotation.id}},
                 prev_el)],
              children);
    
    return h(this.el.tagName, {attrs: this.attrs}, children);
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
