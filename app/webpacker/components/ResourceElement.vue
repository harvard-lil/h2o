<script>
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
    offsetToPoint: {type: Number,
                    default: 0}
  },
  data: function(){
    return {
      node_types: {ELEMENT: 1,
                   TEXT: 3},
      offset: this.offsetToPoint
    }},
  computed: {
    annotations() {
      return this.$store.getters['annotations/getBySectionIndexAndOffsets'](this.index, this.offsetToPoint, this.offsetToPoint + this.el.innerText.length);
    },
    full_annotations() {
      return this.$store.getters['annotations/getBySectionIndexFullSpan'](this.index, this.el.innerText.length);
    },
    childNodesWithOffsets() {
      return Array.from(this.el.childNodes).map(node => {
        let prev_offset = this.offset;
        // uses innerText for element nodes and falls through to
        // textContent for text nodes
        this.offset = this.offset + (node.innerText || node.textContent).length;
        return {node: node, offset: prev_offset};
      })
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
    annotationToComponent(annotation) {
      return ({elide: "elision",
               replace: "replacement"}[annotation.kind] || annotation.kind) + "-annotation";
    }
  },
  render(createElement) {
    let domProps = {};
    let children = [];

    // if there are no annotations or all the annotations span
    // the entire element, use innerHTML to avoid Vue overhead
    if(this.annotations.length == 0 ||
       this.annotations.length == this.full_annotations.length){
      domProps.innerHTML = this.el.innerHTML;
    } else {
      // get the child nodes of the HTMLElement
      // and make them an array we can filter and format
      children = Array.from(this.el.childNodes)
        // remove anything that isn't Text or an Element
        // i.e. no script or comment tags etc
        .filter(node =>
                node.nodeType == this.node_types.TEXT ||
                node.nodeType == this.node_types.ELEMENT)
        .map(node =>
             // if it's a text node, just return the text and
             // Vue will automatically turn it into a 'text VNode'
             node.nodeType == this.node_types.TEXT ? node.textContent
             // else recursively call ResourceElement to loop back through this process
             : createElement("resource-element",
                             {props: {el: node}}));
    }
    return createElement(this.el.tagName,
                         {attrs: this.attrs, domProps: domProps},
                         // Wrap the children in annotations if present
                         this.annotations.reduce((prev_el, annotation) =>
                                                 [createElement(this.annotationToComponent(annotation), {props: {annotationId: annotation.id}}, prev_el)], children));
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
