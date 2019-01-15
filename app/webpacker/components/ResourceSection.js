import store from "../store/index.js.erb";

import ResourceSectionWrapper from "./ResourceSectionWrapper";
import ElisionAnnotation from "./ElisionAnnotation";
import ReplacementAnnotation from "./ReplacementAnnotation";
import HighlightAnnotation from "./HighlightAnnotation";
import LinkAnnotation from "./LinkAnnotation";
import NoteAnnotation from "./NoteAnnotation";

/////////////
// Helpers //
/////////////
    
const kindToComponent = (kind) =>
  ({elide: "elision",
    replace: "replacement"}[kind] || kind) + "-annotation";

const isElement = (node) =>
  node.nodeType == 1;

const isText = (node) =>
  node.nodeType == 3;

const getLength = (node) =>
  (isElement(node) ? node.innerText : node.textContent).length;

const getAttrsMap = (el) => {
  let nodelist = el.attributes;
  let attrmap = {};
  let i = 0;
  for (; i < nodelist.length; i++) {
    attrmap[nodelist[i].name] = nodelist[i].value;
  }
  return attrmap;
};
    
///////////////////////////
// Munging and filtering //
///////////////////////////
    
const isValidNodeType = (node) =>
  isElement(node) || isText(node);
    
const transformToTuplesWithOffsets = (parentStart) =>
  (tuples, node) => {
    let [prevNode, prevStart, prevEnd] = tuples[tuples.length - 1] ||
        [null, null, parentStart];
    return tuples.concat([[node, prevEnd, prevEnd + getLength(node)]]);
  };
    
const splitTextAt = (breakpoints, [node, start, end]) =>
  breakpoints
  // remove any offsets that fall on or outside of the Text node
    .filter(breakpoint =>
            breakpoint > start &&
            breakpoint < end)
  // split the Text node; splitText() mutates the existing node
  // in our array, truncating it, and returns a new node with
  // the remaining text
    .reduce((tuples, breakpoint) => {
      let [prevNode, prevStart, prevEnd] = tuples[tuples.length - 1];
      let node = prevNode.splitText(breakpoint - prevStart);
      tuples[tuples.length - 1][2] = breakpoint;
      return tuples.concat([[node, breakpoint, prevEnd]]);
    }, [[node, start, end]]);

const annotateAndConvertToVNodes = (h, tuples, index, enclosingAnnotationIds) =>
      tuples
      .reduce(insertAnnotations(h, index, enclosingAnnotationIds), [])
      .map(tupleToVNode(h, index, enclosingAnnotationIds));

// Given an annotation and the previous tuple in the list, use the
// annotation's offset information to move forward in the list,
// eagerly grabbing tuples that fall within its range.
// This is the logic that allows annotations to wrap around
// existing elements on the page.
const groupIntoAnnotation = (h, index, tuples, enclosingAnnotationIds) =>
  (prevTuple, annotation) => {
    // Figure out how far to reach forward for elements to group into this annotation.
    // If the annotation extends beyond this section / pararaph,
    // use the end offset of this parent element
    let annotationEndInSection = annotation.end_paragraph == index ? annotation.end_offset : tuples[tuples.length - 1][2];
    // get the forward elements that fall within our range
    let childTuples = [prevTuple, ...tuples.filter(t => t[1] >= prevTuple[2] && t[2] <= annotationEndInSection)];
    let props = {startOffset: prevTuple[1],
                 endOffset: childTuples[childTuples.length - 1][2]};
    
    return [h(kindToComponent(annotation.kind),
              {props: {...props,
                       annotation: annotation}},
              annotateAndConvertToVNodes(h, childTuples, index, enclosingAnnotationIds.concat([annotation.id]))),
            props.startOffset,
            props.endOffset];
  };

// Loop through the tuples and add annotations when found
const insertAnnotations = (h, index, enclosingAnnotationIds) =>
  (modifiedTuples, tuple, idx, orgTuples) => {
    let [node, start, end] = tuple;
    let [prevNode, prevStart, prevEnd] = modifiedTuples[modifiedTuples.length - 1] ||
        [null, null, orgTuples[0][1]];

    // if the previous tuple's end offset is greater than the current tuple's
    // start offset, the current tuple has already been grouped into an
    // annotation's children list so skip it in modifiedTuples so as not
    // to duplicate it in the render
    return prevEnd > start
      ? modifiedTuples
      : modifiedTuples.concat([
        store.getters['annotations/getAtIndexAndOffset'](index, start)
        // longest to shortest
          .sort((a, b) =>
                (b.end_paragraph == index ? b.end_offset : Number.MAX_VALUE) -
                (a.end_paragraph == index ? a.end_offset : Number.MAX_VALUE))
        // Remove any annotations that have already been rendered upstream
          .filter(a => !enclosingAnnotationIds.includes(a.id))
        // We only want the first annotation, for now, but keeping
        // it as an array conveniently allows reduce to
        // return the normal tuple as a default if no annotations exist
          .slice(0, 1)
          .reduce(groupIntoAnnotation(h, index, orgTuples, enclosingAnnotationIds), tuple)]);
  };

// Vue component children arrays must contain either VNodes or
// Strings (which get converted to VNodes automatically)
const tupleToVNode = (h, index, enclosingAnnotationIds = []) =>
  ([node, start, end]) => {
    if(isText(node)) {
      return node.textContent;
    } else if(isElement(node)) {
      return h(node.tagName,
               {attrs: getAttrsMap(node)},
               annotateAndConvertToVNodes(h,
                                          filterAndSplitNodeList(node.childNodes, index, start, end),
                                          index,
                                          enclosingAnnotationIds));
    } else {
      return node;
    }
  };

// Return the offsets within this element where
// annotations need to start or end
const annotationBreakpoints = (index, start, end) =>
      store.getters['annotations/getWithinIndexAndOffsets'](index, start, end)
      .reduce((offsets, annotation) =>
              offsets.concat(
                ["start", "end"]
                  .filter(s => annotation[`${s}_paragraph`] == index)
                  .map(s => annotation[`${s}_offset`]))
              , [])
      .filter((n, i, s) => s.indexOf(n) === i) // remove dupes
      .sort((a, b) => a - b); // sort lowest to highest

const filterAndSplitNodeList = (nodeList, index, start, end) => {
  const breakpoints = annotationBreakpoints(index, start, end);
  return Array.from(nodeList)
  // remove anything that isn't Element or an Text
  // i.e. no script or comment tags etc
    .filter(isValidNodeType)
  // transform our Node array to an array of [Node, start, end] tuples
    .reduce(transformToTuplesWithOffsets(start), [])
  // break next nodes at points where annotations exist
    .reduce((tuples, tuple) => tuples.concat(
      isText(tuple[0])
        ? splitTextAt(breakpoints, tuple)
        : [tuple]
    ), []);
};

export default {
  components: {
    ResourceSectionWrapper,
    ElisionAnnotation,
    ReplacementAnnotation,
    HighlightAnnotation,
    LinkAnnotation,
    NoteAnnotation
  },
  props: {
    el: {type: HTMLElement},
    index: {type: Number}
  },
  render(h) {
    return h("resource-section-wrapper",
             {props: {index: this.index,
                      length: getLength(this.el)}},
             [tupleToVNode(h, this.index)([this.el, 0, getLength(this.el)])]);
  }
};
