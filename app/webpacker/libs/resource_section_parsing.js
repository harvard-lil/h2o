import store from "../store/index";

import { isBlockLevel,
         isElement,
         isText,
         isBR,
         getLength,
         getAttrsMap } from "../libs/html_helpers";

/////////////
// Helpers //
/////////////
    
const kindToComponent = (kind) =>
  ({elide: "elision",
    replace: "replacement"}[kind] || kind) + "-annotation";

export const isFootnoteLink = (node) =>
  !!node.hash && node.origin == location.origin && node.pathname == location.pathname;

const getTagName = (node) =>
  isFootnoteLink(node) ? "footnote-link" : node.tagName;

const last = (array) =>
  array[array.length - 1];
    
///////////////////////////
// Munging and filtering //
///////////////////////////
    
const isValidNodeType = (node) =>
  isElement(node) || isText(node);
    
export const transformToTuplesWithOffsets = (parentStart) =>
  (tuples, node) => {
    let [prevNode, prevStart, prevEnd] = last(tuples) ||
        [null, null, parentStart];
    return tuples.concat([[node, prevEnd, prevEnd + getLength(node)]]);
  };
    
export const splitTextAt = (breakpoints, [node, start, end]) =>
  breakpoints
    // remove any offsets that fall on or outside of the Text node
    .filter(breakpoint =>
            breakpoint > start &&
            breakpoint < end)
    // split the Text node; splitText() mutates the existing node
    // in our array, truncating it, and returns a new node with
    // the remaining text
    .reduce((tuples, breakpoint) => {
      let [prevNode, prevStart, prevEnd] = last(tuples);
      let node = prevNode.splitText(breakpoint - prevStart);
      last(tuples)[2] = breakpoint;
      return tuples.concat([[node, breakpoint, prevEnd]]);
    }, [[node, start, end]]);

const annotateAndConvertToVNodes = (h, tuples, index, enclosingAnnotationIds) =>
      tuples
      .reduce(insertAnnotations(h, index, enclosingAnnotationIds), [])
      .map(tupleToVNode(h, index, enclosingAnnotationIds));

// Find nodes that are within a range of offsets, stopping at the first
// block level element found. Allows us to greedily group nodes into
// annotations without grouping block level elements into them.
const sequentialInlineNodesWithinRange = (tuples, start, end) => {
  let inRange = tuples.filter(t => t[1] >= start && t[2] <= end);
  const firstBlock = inRange.findIndex(t => isBlockLevel(t[0]));
  return firstBlock == -1 ? inRange : inRange.slice(0, firstBlock);
};

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
    let annotationEndInSection = annotation.end_paragraph == index ? annotation.end_offset : last(tuples)[2];
    // get the forward elements that fall within our range
    let childTuples = [prevTuple, ...sequentialInlineNodesWithinRange(tuples, prevTuple[2], annotationEndInSection)];
    let props = {startOffset: prevTuple[1],
                 endOffset: last(childTuples)[2]};
    
    return [h(kindToComponent(annotation.kind),
              {key: `${annotation.id}:${index}/${props.startOffset}-${props.endOffset}`,
               props: {...props,
                       index: index,
                       annotation: annotation}},
              annotateAndConvertToVNodes(h, childTuples, index, enclosingAnnotationIds.concat([annotation.id]))),
            props.startOffset,
            props.endOffset];
  };

// Loop through the tuples and add annotations when found
const insertAnnotations = (h, index, enclosingAnnotationIds) =>
  (modifiedTuples, tuple, idx, orgTuples) => {
    let [node, start, end] = tuple;
    let [prevNode, prevStart, prevEnd] = last(modifiedTuples) ||
        [null, null, orgTuples[0][1]];

    // If the previous tuple's end offset is greater than the current tuple's
    // start offset, the current tuple has already been grouped into an
    // annotation's children list so skip it in modifiedTuples so as not
    // to duplicate it in the render
    if(prevEnd > start) {
      return modifiedTuples;
      // If this is a block level element, don't wrap it since annotations
      // use <span>s in order to wrap the text as lines, rather than a block,
      // and wrapping block level elements with inline elements is forbidden.
      // The script will instead recurse into this node later on and wrap the
      // content contained therein.
    } else if(isBlockLevel(node)){
      return modifiedTuples.concat([tuple]);
    } else {
      return modifiedTuples.concat([
        store.getters['annotations/getSpanningOffsets'](index, start, end)
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
    // remove anything that isn't an Element or Text node
    // i.e. no script or comment tags etc
    .filter(isValidNodeType)
    // transform our Node array to an array of [Node, start, end] tuples
    .reduce(transformToTuplesWithOffsets(start), [])
    // break text nodes at points where annotations exist
    .reduce((tuples, tuple) => tuples.concat(
      isText(tuple[0])
        ? splitTextAt(breakpoints, tuple)
        : [tuple]
    ), []);
};

// Vue component children arrays must contain either VNodes or
// Strings (which get converted to VNodes automatically)
export const tupleToVNode = (h, index, enclosingAnnotationIds = []) =>
  ([node, start, end]) => {
    if(isText(node)) {
      return node.textContent;
    } else if(isElement(node)) {
      let tag = getTagName(node),
          data = {attrs: getAttrsMap(node)},
          children = annotateAndConvertToVNodes(h, filterAndSplitNodeList(node.childNodes, index, start, end), index, enclosingAnnotationIds);
      switch(tag) {
      case "footnote-link":
        data.props = {enclosingAnnotationIds: enclosingAnnotationIds};
        break;
      }
      return h(tag, data, children);
    } else {
      return node;
    }
  };
