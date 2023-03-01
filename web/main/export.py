import logging
import re
from typing import Any

from django.utils.safestring import SafeText, mark_safe
from lxml import html, sax
from pyquery import PyQuery

from main.models import ContentAnnotation, ContentNode

from .utils import block_level_elements, remove_empty_tags, void_elements

SortedAnnotation = tuple[int, bool, ContentAnnotation]

logger = logging.getLogger(__name__)


class AnnotationContentHandler(sax.ContentHandler):
    def __init__(self, annotations: list[SortedAnnotation], postfix_id: int, export_options: dict):
        # internal state:
        self.offset = 0  # current offset in the text stream
        self.elide = 0  # Greater than 0 if characters are currently being elided
        self.wrap_before_tags: list = []  # before emitting a tag, close these
        self.wrap_after_tags: list = []  # after emitting a tag, re-open these
        self.footnote_index = 0  # footnote count
        self.prev_tag = None  # previous source tag emitted
        self.skip_next_wrap_before = (
            False  # whether to apply wrap_before_tags to the next element emitted
        )
        self.annotations = annotations
        self.postfix_id = postfix_id
        self.export_options = export_options

        # output state:
        self.out_handler = (
            sax.ElementTreeContentHandler()
        )  # the sax ContentHandler that will be used to generate the output
        self.out_ops: list[Any] = []  # list of operations to apply to the out_handler

    ## event handlers

    def characters(self, data):
        """
        Called when the SAX parser encounters a text string in the source HTML. Handle each annotation
        within the current string.
        """
        # calculate the range of annotations affected by this string:
        start_offset = self.offset
        self.offset = end_offset = start_offset + len(data)

        # special case -- don't annotate empty whitespace that comes after a block tag, because annotating
        # non-printing whitespace would insert empty paragraphs in the output:
        if (
            # ... we have annotation spans open
            self.wrap_after_tags
            and
            # ... previous tag was closing a block-level element
            self.prev_tag
            and self.prev_tag[0] == self.out_handler.endElement
            and self.prev_tag[1] in block_level_elements
            and
            # ... text after tag is whitespace
            re.match(r"\s*$", data)
            and
            # ... the text is not annotated
            ((not self.annotations) or end_offset < self.annotations[0][0])
        ):
            # remove the open spans added by the previous /tag
            self.out_ops = self.out_ops[: -len(self.wrap_after_tags)]
            # prevent spans from closing before the next tag
            self.skip_next_wrap_before = True

        # Process each annotation within this character range.
        # Include end annotations that come after the final character of the string, but NOT start annotations,
        # so that annotations tend to go inside block tags -- start annotations go to the right of tags
        # and end annotations go to the left.
        while self.annotations and (
            end_offset > self.annotations[0][0]
            or (end_offset == self.annotations[0][0] and not self.annotations[0][1])
        ):
            annotation_offset, is_start_tag, annotation = self.annotations.pop(0)

            # consume and emit the text that comes before this annotation:
            if annotation_offset > start_offset:
                split = annotation_offset - start_offset
                if not self.elide:
                    self.addText(data[:split])
                data = data[split:]
                start_offset = annotation_offset

            # handle the annotation
            kind = annotation.kind
            if kind == "replace" or kind == "elide":
                # replace/elide tags are simpler because we don't need to do anything special for annotations
                # that span paragraphs. Just emit the elision text and increment elide when opening the tag,
                # and decrement when closing. Use a counter for elide instead of a boolean so we handle
                # overlapping elision ranges correctly (though those shouldn't happen in practice).
                if is_start_tag:
                    self.out_ops.append(
                        (
                            self.out_handler.startElement,
                            "span",
                            {
                                "data-custom-style": "Elision"
                                if kind == "elide"
                                else "Replacement Text"
                            },
                        )
                    )
                    self.addText(annotation.content or "" if kind == "replace" else "[ … ]")
                    self.out_ops.append((self.out_handler.endElement, "span"))
                    self.elide += 1
                else:
                    self.elide = max(self.elide - 1, 0)  # decrement, but no lower than zero
            elif kind == "correction":
                if is_start_tag:
                    self.elide += 1
                    self.addText(annotation.content or "")
                else:
                    self.elide = max(self.elide - 1, 0)  # decrement, but no lower than zero
            else:  # kind == 'link' or 'note' or 'highlight'
                # link/note/highlight tags require wrapping all subsequent text in <span> tags.
                # In addition to emitting the open tags themselves, also add the open and close tags to
                # wrap_before_tags and wrap_after_tags so that every tag we encounter can be wrapped with
                # close and open tags for all open annotations.
                if is_start_tag:
                    # get correct open and close tags for this annotation:
                    if kind == "link":
                        open_tag = (
                            self.out_handler.startElement,
                            "a",
                            {"href": annotation.content, "class": "annotate"},
                        )
                        close_tag = (self.out_handler.endElement, "a")
                    elif kind == "note":
                        open_tag = (
                            self.out_handler.startElement,
                            "span",
                            {"class": "annotate"},
                        )
                        close_tag = (self.out_handler.endElement, "span")
                    elif kind == "highlight":
                        open_tag = (
                            self.out_handler.startElement,
                            "span",
                            {
                                "class": "annotate highlighted",
                                "data-custom-style": "Highlighted Text",
                            },
                        )
                        close_tag = (self.out_handler.endElement, "span")
                    else:
                        raise ValueError(f"Unknown annotation kind '{kind}'")

                    # emit the open tag itself:
                    self.out_ops.append(open_tag)

                    # track that the tag is currently open:
                    self.wrap_after_tags.append(open_tag)
                    self.wrap_before_tags.insert(0, close_tag)
                    annotation.open_tag = open_tag
                    annotation.close_tag = close_tag
                else:
                    # close the annotation tag:
                    # to handle overlapping annotations, close all tags including this one, and then re-open all tags except this one:
                    self.wrap_after_tags.remove(annotation.open_tag)
                    self.out_ops.extend(self.wrap_before_tags + self.wrap_after_tags)
                    self.wrap_before_tags.remove(annotation.close_tag)

                    # emit the footnote marker:
                    if kind == "note" or kind == "link":
                        self.footnote_index += 1
                        footnote_ref = "Footnote Reference" + (
                            f"-{self.postfix_id}"
                            if self.export_options
                            and self.export_options.get("docx_footnotes", False)
                            else ""
                        )
                        self.out_ops.append(
                            (
                                self.out_handler.startElement,
                                "span",
                                {"data-custom-style": footnote_ref},
                            )
                        )
                        self.addText("*" * self.footnote_index)
                        self.out_ops.append((self.out_handler.endElement, "span"))

        # emit any text that comes after the final annotation in this text string:
        if data and not self.elide:
            self.addText(data)

    def startElementNS(self, name: tuple[str, str], qname, attributes):
        """Handle opening elements from the source HTML."""
        if self.omitTag(name[1]):
            return
        if attributes and (None, "data-extra-export-offset") in attributes:
            extra_offset = int(attributes.getValueByQName("data-extra-export-offset"))
            self.offset -= extra_offset
        self.addTag(
            (
                self.out_handler.startElement,
                name[1],
                {k[1]: v for k, v in attributes.items()},
            )
        )

    def endElementNS(self, name: tuple[str, str], qname):
        """Handle closing elements from the source HTML."""
        if self.omitTag(name[1]):
            return
        self.addTag((self.out_handler.endElement, name[1]))

    ## helpers

    def addTag(self, tag):
        """Add a tag from the source HTML, wrapped with the currently open annotation tags."""
        if self.skip_next_wrap_before:
            self.out_ops.extend([tag] + self.wrap_after_tags)
            self.skip_next_wrap_before = False
        else:
            self.out_ops.extend(self.wrap_before_tags + [tag] + self.wrap_after_tags)
        self.prev_tag = tag

    def addText(self, text):
        self.out_ops.append((self.out_handler.characters, text))

    def omitTag(self, tag):
        """
        True if a tag from the source HTML should be omitted. This is True if we are currently in an
        elided section, and this is a void element like '<br>'. We can't omit matched elements like
        '<p>' because the elided section may end before we reach the closing '</p>'. Instead it's fine
        to emit '<p></p>', which will later be filtered out by remove_empty_tags().
        """
        return self.elide and tag in void_elements

    def get_output_tree(self):
        """Render and return the lxml content tree from out_handler."""
        # each entry in out_ops will be a method on out_handler and a list of arguments, like
        # (self.out_handler.startElement, 'span')
        for method, *args in self.out_ops:
            try:
                method(*args)
            except sax.SaxError as e:
                logger.warning(f"Got SAX error when reserializing: {e}")
        return self.out_handler.etree.getroot()


def annotated_content_for_export(node: ContentNode, export_options: dict = None) -> SafeText:

    export_options = export_options or {}
    doc = node.headerless_export_content(export_options.get("request"))
    if not doc:
        return doc
    pq = PyQuery(doc)
    source_tree = pq[0]
    max_valid_offset = len("".join([x for x in pq[0].itertext()]))
    annotations: list[SortedAnnotation] = []
    for annotation in node.annotations.all():
        # equivalent test to self.annotation.valid(),but using all() lets us use prefetched querysets
        if annotation.global_start_offset < 0 or annotation.global_end_offset < 0:
            continue
        annotations.append(
            (min(annotation.global_start_offset, max_valid_offset), True, annotation)
        )
        annotations.append((min(annotation.global_end_offset, max_valid_offset), False, annotation))
    # sort by first two fields, so we're ordered by offset, then we get end tags and then start tags for a given offset
    annotations.sort(key=lambda a: (a[0], not a[1]))
    # This SAX ContentHandler does the heavy lifting of stepping through each HTML tag and text string in the
    # source HTML and building a list of destination tags and text, inserting annotation tags or deleting text
    # as appropriate:

    # use AnnotationContentHandler to insert annotations in our content HTML:
    handler = AnnotationContentHandler(
        annotations=annotations, postfix_id=node.id, export_options=export_options
    )
    sax.saxify(source_tree, handler)
    dest_tree = handler.get_output_tree()

    # clean up the output tree:
    remove_empty_tags(dest_tree)  # tree may contain empty tags from elide/replace annotations
    # apply general rules that are the same for annotated or un-annotated trees
    return mark_safe(
        node.rendered_header()
        + node.export_postprocess(
            html.tostring(dest_tree).decode("utf-8"), export_options=export_options
        )
    )
