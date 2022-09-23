import { Previewer } from "pagedjs";

/**
 *  Collect groups of ranges for each annotation offset start and end. Note that start/end offset may
 * cross multiple block-level node boundaries; this will construct one node range for each block-level element.
 * @param  {NodeList} annotations The list of annotation elements in the parent DOM injected by Django.
 * @param {DocumentFragment} content The DOM content of the page
 * @returns {Object[]} an array of objects containing the annotation type, the timestamp of the annotation,
 *  and an array of ranges
 */
function annotationsToRanges(annotations, content) {
  const annotationRanges = annotations.map((el) => {
    let ranges = [],
      currentOffset = 0,
      textNode, // The current text node we're processing
      startNode, // The text node we've identified as the start of the annotation
      endNode; // The text node we've identified that contains the end of the annotation

    // Get the content from the DOM that matches this annotation, and its offset values
    const resource = content.querySelector(
      `[data-node-id="${el.getAttribute("data-node-id")}"]`
    );
    const startOffset = +el.getAttribute("data-start-offset");
    const endOffset = +el.getAttribute("data-end-offset");

    const iter = document.createNodeIterator(resource, NodeFilter.SHOW_TEXT);

    // Iterate through all the text nodes in the resource, keeping track of the current character offset.
    // Early exit when we've found the end of the annotation.
    while ((textNode = iter.nextNode()) && !endNode) {
      const chars = textNode.textContent?.length;

      // If the annotation's start offset lies within this node...
      if (currentOffset + chars > startOffset && !startNode) {
        // ...mark the node as the start node
        startNode = textNode;

        // Create a new Range to express the annotation within this node
        const range = new Range();

        // Range offsets are relative to the parent node, so derive a relative offset by dropping
        // the characters we've skipped over already
        range.setStart(startNode, startOffset - currentOffset);

        // If the annotation ends naturally inside this text node, set the end offset with
        // the same relative logic as the start node, and mark this node as the end
        if (endOffset <= currentOffset + chars) {
          range.setEnd(startNode, endOffset - currentOffset);
          endNode = startNode;
        }
        // Otherwise, the annotation ends in a subsequent node, so end this particular range
        // at the end of this node's block of characters.
        else {
          range.setEnd(startNode, chars);
        }
        // Save off this range
        ranges.push(range);
      }
      // If the start of the annotation was found but the end has not been...
      else if (startNode && !endNode) {
        // Any intermediate or final range will naturally start at the beginning of this node
        const range = new Range();
        range.setStart(textNode, 0);

        // and end either within this node, or in a following one
        if (endOffset < currentOffset + chars) {
          endNode = textNode;
          range.setEnd(endNode, endOffset - currentOffset);
        } else {
          range.setEnd(textNode, chars);
        }
        ranges.push(range);
      }
      currentOffset += chars;
    }

    return {
      type: el.getAttribute("data-annotation-type"),
      datetime: el.getAttribute("data-datetime"),
      content: el.textContent,
      ranges,
    };
  });
  return annotationRanges;
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("main").forEach((main) => {
    const tmpl = document.querySelector("#casebook-content");
    const css = tmpl.getAttribute("data-stylesheet");
    const paged = new Previewer();

    const annotationRanges = annotationsToRanges(
      Array.from(tmpl.content.querySelectorAll("[data-annotation-type]")),
      tmpl.content
    );

    // When all Ranges are ready, start updating the DOM
    annotationRanges.forEach((rg) => {
      const { type, datetime, ranges, content } = rg;
      switch (type) {
        case "highlight": {
          ranges.forEach((range) => {
            const wrap = document.createElement("span");
            wrap.classList.add("highlighted");
            range.surroundContents(wrap);
          });
          break;
        }
        case "elide": {
          ranges.forEach((range) => {
            const elision = document.createElement("del");
            elision.classList.add("elided");
            elision.setAttribute("datetime", datetime);

            const marker = document.createElement("ins");
            marker.classList.add("elision-marker");
            marker.innerText = " … ";
            range.surroundContents(elision);
            elision.insertAdjacentElement("afterend", marker);

            // If the previous sibling is another marker, or if it's an empty text node,
            // hide the marker
            if (
              elision.previousSibling.classList?.contains("elision-marker") ||
              elision.previousSibling.textContent.trim() === ""
            ) {
              marker.classList.add("hidden");
            }
          });
          break;
        }
        case "note": {
          let lastRange;

          ranges.forEach((range) => {
            const wrap = document.createElement("span");
            wrap.classList.add("highlighted");
            range.surroundContents(wrap);
            lastRange = wrap;
          });
          // Add the note after the last range
          const note = document.createElement("aside");
          note.classList.add("authors-note");
          note.innerHTML = `<h4>Author’s note:</h4>
            <blockquote>${content}</blockquote>
          `;
          lastRange.insertAdjacentElement("afterend", note);
          break;
        }
      }
    });

    paged.preview(tmpl.content, [css], main).then((flow) => {
      console.log("Rendered", flow.total, "pages.");
    });
  });
});
