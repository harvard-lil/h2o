import { isBlockLevel,
         isElement,
         isText,
         getLength,
         getAttrsMap } from "../libs/html_helpers";
import _ from 'lodash';

/////////////
// Helpers //
/////////////
    
const kindToComponent = (kind) =>
  ({elide: "elision",
    replace: "replacement"}[kind] || kind) + "-annotation";

export const isFootnoteLink = (node) =>
  Boolean(node.hash) && node.origin == location.origin && node.pathname == location.pathname;

const getTagName = (node) =>
  isFootnoteLink(node) ? "footnote-link" : node.getAttribute("is") || node.tagName;

const last = (array) =>
  array[array.length - 1];

///////////////
// Filtering //
///////////////

export const nodeToTuple = (node, prevEnd = 0) =>
  [node, prevEnd, prevEnd + getLength(node)];

export const nodesToTuples = (parentStart) =>
  (tuples, node) => {
    let [_prevNode, _prevStart, prevEnd] = last(tuples) ||
        [null, null, parentStart];
    return tuples.concat([nodeToTuple(node, prevEnd)]);
  };
    
export const splitTextAt = (breakpoints, [node, start, end]) =>
  breakpoints
    // remove any offsets that fall on or outside of the Text node
    .filter(breakpoint => breakpoint > start && breakpoint < end)
    // split the Text node; splitText() mutates the existing node
    // in our array, truncating it, and returns a new node with
    // the remaining text
    .reduce((tuples, breakpoint) => {
      let [prevNode, prevStart, prevEnd] = last(tuples);
      let node = prevNode.splitText(breakpoint - prevStart);
      last(tuples)[2] = breakpoint;
      return tuples.concat([[node, breakpoint, prevEnd]]);
    }, [[node, start, end]]);

const annotateAndConvertToVNodes = (h, annotations, tuples) =>
      tuples
      .reduce(insertAnnotations(h, annotations), [])
      .map(tupleToVNode(h, annotations));

// Find nodes that are within a range of offsets, stopping at the first
// block level element found. Allows us to greedily group nodes into
// annotations without grouping block level elements into them.
export const sequentialInlineNodesWithinRange = (tuples, start, end) => {
  let inRange = tuples.filter(t => t[1] >= start && t[2] <= end);
  const firstBlock = inRange.findIndex(t => isBlockLevel(t[0]));
  return firstBlock == -1 ? inRange : inRange.slice(0, firstBlock);
};

// Given an annotation and the previous tuple in the list, use the
// annotation's offset information to move forward in the list,
// eagerly grabbing tuples that fall within its range.
// This is the logic that allows annotations to wrap around
// existing elements on the page.
const groupIntoAnnotation = (h, annotations, tuples) =>
  (prevTuple, annotation) => {
    // Figure out how far to reach forward for elements to group into this annotation.
    // get the forward elements that fall within our range
    let childTuples = [prevTuple, ...sequentialInlineNodesWithinRange(tuples, prevTuple[2], annotation.end_offset)];

    // Vue will strip single spaces between annotation tags, unless
    // within a PRE tag, so we create a special component to handle this
    // Details: https://github.com/harvard-lil/h2o/issues/680
    // Vue's logic for what gets stripped:
    // https://github.com/vuejs/vue/blob/e90cc60c4718a69e2c919275a999b7370141f3bf/dist/vue.esm.js#L2541-L2543
    if(childTuples.length === 1 &&
       isText(childTuples[0][0]) &&
       childTuples[0][0].textContent === ' '){
      const pre = document.createElement("PRE");
      pre.setAttribute("is", "space-preserver");
      childTuples[0][0] = pre;
    }

    let props = {startOffset: prevTuple[1],
                 endOffset: last(childTuples)[2],
                 isHead: !annotation.used};
    annotation.used = true;

    return [h(kindToComponent(annotation.kind),
              {key: `${annotation.id}/${props.startOffset}-${props.endOffset}`,
               props: {...props,
                       annotation: annotation}},
              // remove this annotation from the set so the children don't duplicate it in their renders
              annotateAndConvertToVNodes(h, annotations.filter(a => a != annotation), childTuples)),
            props.startOffset,
            props.endOffset];
  };

// Loop through the tuples and add annotations when found
const insertAnnotations = (h, annotations) =>
  (modifiedTuples, tuple, idx, orgTuples) => {
    let [node, start, end] = tuple;
    let [_prevNode, _prevStart, prevEnd] = last(modifiedTuples) ||
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
        annotations
        // Annotations that entirely span (or exceed) the provided offsets.
          .filter(obj => obj.start_offset <= start && obj.end_offset >= end)
        // longest to shortest
          .sort((a, b) => b.end_offset - a.end_offset)
        // We only want the first annotation, for now, but keeping
        // it as an array conveniently allows reduce to
        // return the normal tuple as a default if no annotations exist
          .slice(0, 1)
          .reduce(groupIntoAnnotation(h, annotations, orgTuples), tuple)]);
    }
  };

// Return the offsets within this element where
// annotations need to start or end
export const annotationBreakpoints = (annotations, start, end) =>
  annotations
    // Annotations whose start or end points fall WITHIN
    // (i.e. not on the edges) the start and end bounds.
    .filter(a => a.start_offset > start || a.end_offset < end)
    .reduce((breakpoints, a) => breakpoints.concat([a["start_offset"], a["end_offset"]]), [])
    .filter((breakpoint, index, breakpoints) => breakpoints.indexOf(breakpoint) === index) // remove dupes
    .sort((a, b) => a - b); // sort lowest to highest

export const splitNodeList = (annotations, nodeList, start, end) => {
  const breakpoints = annotationBreakpoints(annotations, start, end);
  return Array.from(nodeList)
    // transform our Node array to an array of [Node, start, end] tuples
    .reduce(nodesToTuples(start), [])
    // break text nodes at points where annotations exist
    .reduce((tuples, tuple) => tuples.concat(
      isText(tuple[0])
        ? splitTextAt(breakpoints, tuple)
        : [tuple]
    ), []);
};


const isFullyElided = (node) => {
    if (_.isString(node)) {
        return false;
    } else {
        if (node.tag && (_.endsWith(node.tag,'elision-annotation') || _.endsWith(node.tag,'replacement-annotation'))) {
            return true;
        }
        if (node.classList && node.classList.indexOf("fully-elided") > -1){
            return true;
        }
        if (node.data && node.data.class && node.data.class['fully-elided']) {
            return true;
        }
        return false;
    }
}

// Vue component children arrays must contain either VNodes or
// Strings (which get converted to VNodes automatically)
export const tupleToVNode = (h, annotations) =>
  ([node, start, end]) => {
    if(isText(node)) {
      return node.textContent;
    } else if(isElement(node)) {
      // "is" is a Vue property that shouldn't be added to the final html
      // See: https://vuejs.org/v2/guide/components.html#DOM-Template-Parsing-Caveats
      let attrs = getAttrsMap(node);
      delete attrs.is;

      let tag = getTagName(node),
          data = {attrs: attrs},
          children = annotateAndConvertToVNodes(h, annotations, splitNodeList(annotations, node.childNodes, start, end));
      switch(tag) {
      case "footnote-link":
          data.props = {startOffset: start,
                      endOffset: end};
          break;
      }
        if (_.some(children,isFullyElided)) {
            const presentChildren = children.filter(x => !isFullyElided(x));
            if (_.every(presentChildren, x => _.isString(x) && x.trim() === "")) {
                data.class = {'fully-elided': true};
            }
        }
      return h(tag, data, children);
    } else {
      return node;
    }
  };
