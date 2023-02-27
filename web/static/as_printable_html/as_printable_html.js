class TocControl extends HTMLElement {
  static get observedAttributes() {
    return ["open"];
  }

  connectedCallback() {
    this.tocList = this.querySelector("ol");
    if (this.tocList) {
      this.querySelector(".toc-opener").addEventListener("click", () => {
        this.toggleAttribute("open");
      });
    }
  }
}

customElements.define("toc-control", TocControl);

/**
 * Collect groups of ranges for each annotation offset start and end. Note that start/end offset may
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
      const chars = textNode.textContent?.length || 0;

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
        if (endOffset <= currentOffset + chars) {
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
      id: el.getAttribute("data-annotation-id"),
      type: el.getAttribute("data-annotation-type"),
      datetime: el.getAttribute("data-datetime"),
      content: el.textContent,
      ranges,
    };
  });
  return annotationRanges;
}

/**
 * Create a footnote element in PagedJS containing the provided URL.
 * @param {Node} node
 * @param {string} url
 * @param {Date} dateCreated
 */
function hyperlinkFootnote(node, url, dateCreated) {
  const footnote = document.createElement("a");
  footnote.setAttribute("href", url);
  const displayDate = dateCreated.toLocaleString("en-US", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
  footnote.innerHTML = `${url}
    <span class="citation">(link created ${displayDate})</span>`;
  node.insertAdjacentElement("afterend", footnote);
}

const main = document.querySelector("main");

const annotationRanges = annotationsToRanges(
  Array.from(main.querySelectorAll("[data-annotation-type]")),
  main
);

// When all Ranges are ready, start updating the DOM

annotationRanges.forEach((rg) => {
  const { id, type, datetime, ranges, content } = rg;
  switch (type) {
    case "highlight": {
      ranges.forEach((range) => {
        const wrap = document.createElement("mark");
        wrap.setAttribute("highlight-id", id);
        wrap.classList.add("highlighted");
        range.surroundContents(wrap);
      });
      break;
    }
    case "elide": {
      let firstNode;
      ranges
        .filter((range) => range.endOffset > 0)
        .forEach((range) => {
          const elision = document.createElement("del");

          elision.classList.add("elided");

          elision.setAttribute("datetime", datetime);
          elision.setAttribute("data-elision-id", id);
          elision.setAttribute("data-range-start", range.startOffset);
          elision.setAttribute("data-range-end", range.endOffset);
          range.surroundContents(elision);
          if (!firstNode) {
            firstNode = elision;
          }
        });
      if (firstNode) {
        const marker = `<ins data-elision-marker-id="${id}" datetime="${datetime}" class="elision-marker"> […] </ins>`;
        // Put the insertion marked outside the containing node if the elided content is the first real content of its parent;
        // this avoids inheriting spurious markup from the elided parent.
        if (firstNode.parentNode.firstChild === firstNode) {
          firstNode.parentNode.insertAdjacentHTML("beforebegin", marker);
        } else if (
          firstNode.parentNode.firstElementChild == firstNode &&
          firstNode.previousSibling.textContent.trim().length === 0
        ) {
          firstNode.parentNode.insertAdjacentHTML("beforebegin", marker);
        } else {
          firstNode.insertAdjacentHTML("beforebegin", marker);
        }
      }
      break;
    }
    case "note": {
      let lastNode;

      // Wrap the specific text the author highlighted to allow for downstream styling
      ranges.forEach((range) => {
        const wrap = document.createElement("mark");
        wrap.setAttribute("mark-id", id);
        wrap.setAttribute("tabindex", "0");
        wrap.classList.add("note-mark");
        range.surroundContents(wrap);
        lastNode = wrap;
      });

      // Add the note after the last range
      const note = `<aside note-id="${id}" class="authors-note">${content}</aside>`;
      lastNode.insertAdjacentHTML("afterend", note);

      break;
    }
    case "replace":
    case "correction": {
      let lastNode;
      // Transparently replace the content inside the node
      ranges.forEach((range) => {
        const deletion = document.createElement("del");
        deletion.setAttribute("correction-deletion-id", id);
        deletion.setAttribute("datetime", datetime);
        deletion.classList.add(type);
        range.surroundContents(deletion);
        lastNode = deletion;
      });
      const replacement = `<ins data-${type}-insertion-id="${id}" datetime="${datetime}" class="${type}">${content}</ins>`;
      lastNode.insertAdjacentHTML("afterend", replacement);
      break;
    }
    case "link":
      // Inject a hyperlink which in print will be styled as a footnote
      ranges.forEach((range) => {
        const anchor = document.createElement("a");
        anchor.setAttribute("href", content);
        range.surroundContents(anchor);
        hyperlinkFootnote(anchor, content, new Date(datetime));
      });
      break;
  }
});

// Any existing URLs that are external and don't open in a new tab should
main.querySelectorAll('a[href^="http"]:not([target])').forEach((el) => {
  requestAnimationFrame(
    () => {
      el.setAttribute("target", "_blank");
    },
    { timeout: 500 }
  );
});

// Uniquify id links within case content
requestAnimationFrame(
  () => {
    for (const casebody of main.querySelectorAll(".casebody")) {
      const caseId = casebody.getAttribute("data-case-id");
      for (const link of casebody.querySelectorAll('a[id^="ref"')) {
        link.setAttribute("id", `${link.id}-${caseId}`);
      }
      for (const link of casebody.querySelectorAll('a[href^="#"')) {
        const targetId = link.getAttribute("href").replace("#", "");
        const newId = `${targetId}-${caseId}`;
        casebody
          .querySelector(`[id="${targetId}]"`)
          ?.setAttribute("name", newId);
        link.setAttribute("href", `#${newId}`);
      }
    }
  },
  { timeout: 600 }
);

document.querySelector("#page-selector").addEventListener("change", (e) => {
  location.href = e.target.value;
});
