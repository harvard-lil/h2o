import { Previewer } from "pagedjs";

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("main").forEach((main) => {
    const tmpl = document.querySelector("#casebook-content");
    const css = tmpl.getAttribute("data-stylesheet");
    const paged = new Previewer();

    // Collect groups of ranges for each highlight offset start and end. Note that start/end offset may
    // cross multiple block-level node boundaries; this will construct one node range for each block-level element.
    const highlightRanges = Array.from(
      tmpl.content.querySelectorAll('[data-annotation-type="highlight"]')
    ).map((el) => {
      let ranges = [],
        currentOffset = 0,
        textNode, // The current textNode we're processing
        startNode, // The text node we've identified as the start of the highlight
        endNode; // The text node we've identified that contains the end of the highlight

      // Get the content from the DOM that matches this highlight, and its offset values
      const resource = tmpl.content.querySelector(
        `[data-node-id="${el.textContent}"]`
      );
      const startOffset = +el.getAttribute("data-start-offset");
      const endOffset = +el.getAttribute("data-end-offset");

      const iter = document.createNodeIterator(resource, NodeFilter.SHOW_TEXT);

      // Iterate through all the text nodes in the resource, keeping track of the current character offset.
      // Early exit when we've found the end of the highlight.
      while ((textNode = iter.nextNode()) && !endNode) {
        const chars = textNode.textContent?.length;

        // If the highlight start offset lies within this node...
        if (currentOffset + chars > startOffset && !startNode) {
          // ...mark the node as the start node
          startNode = textNode;

          // Create a new Range to express the highlight within this node
          const range = new Range();

          // Range offsets are relevant to the parent node, so derive a relative offset by dropping
          // the characters we've skipped over already
          range.setStart(startNode, startOffset - currentOffset);

          // If the highlight ends naturally inside this text node, set the end offset with
          // the same relative logic as the start node, and mark this node as the end
          if (endOffset < currentOffset + chars) {
            range.setEnd(startNode, endOffset - currentOffset);
            endNode = startNode;
          }
          // Otherwise, the highlight ends in a subsequent node, so end this particular range
          // at the end of this node's block of characters.
          else {
            range.setEnd(startNode, chars);
          }
          // Save off this range
          ranges.push(range);
        }
        // If the start of the highlight was found but the end has not been...
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

      console.groupEnd();
      return ranges;
    });

    // When all Ranges are ready, start updating the DOM
    highlightRanges.forEach((rangeGroup) => {
      rangeGroup.forEach((range) => {
        const wrap = document.createElement("span");
        wrap.classList.add("highlighted");
        range.surroundContents(wrap);
      });
    });

    paged.preview(tmpl.content, [css], main).then((flow) => {
      console.log("Rendered", flow.total, "pages.");
    });
  });
});
