from rest_framework.response import Response

from main.utils import re_split_offsets


def check_response(response, status_code=200, content_type=None, content_includes=None, content_excludes=None):
    assert response.status_code == status_code

    # check content-type if not a redirect
    if response['content-type']:
        # For rest framework response, expect json; else expect html.
        if not content_type:
            if type(response) == Response:
                content_type = "application/json"
            else:
                content_type = "text/html"
        assert response['content-type'].split(';')[0] == content_type

    content = response.content.decode()
    if content_includes:
        if isinstance(content_includes, str):
            content_includes = [content_includes]
        for content_include in content_includes:
            assert content_include in content
    if content_excludes:
        if isinstance(content_excludes, str):
            content_excludes = [content_excludes]
        for content_exclude in content_excludes:
            assert content_exclude not in content


def dump_casebook_outline(casebook):
    """
        Helper function to serialize the full tree for a casebook, for testing casebook clone/merge functions.

        >>> reset_sequences, full_casebook = [getfixture(i) for i in ['reset_sequences', 'full_casebook']]
        >>> assert dump_casebook_outline(full_casebook) == [
        ...     'Casebook<1>: Some Title 0',
        ...     ' Section<2>: Some Section 1',
        ...     '  ContentNode<3> -> TextBlock<1>: Some TextBlock Name 0',
        ...     '  ContentNode<4> -> Case<1>: Foo Foo0 vs. Bar Bar0',
        ...     '   ContentAnnotation<1>: highlight 0-10',
        ...     '   ContentAnnotation<2>: elide 0-10',
        ...     '  ContentNode<5> -> Default<1>: Some Link Name 0',
        ...     '  Section<6>: Some Section 5',
        ...     '   ContentNode<7> -> TextBlock<2>: Some TextBlock Name 1',
        ...     '   ContentNode<8> -> Case<2>: Foo Foo1 vs. Bar Bar1',
        ...     '    ContentAnnotation<3>: note 0-10',
        ...     '    ContentAnnotation<4>: replace 0-10',
        ...     '   ContentNode<9> -> Default<2>: Some Link Name 1',
        ...     ' Section<10>: Some Section 9',
        ... ]
    """
    out = []
    out.append("Casebook<%s>: %s" % (casebook.id, casebook.title))
    for node in casebook.contents.prefetch_resources().prefetch_related('annotations'):
        node_type = node.type
        indent = " " * len(node.ordinals)
        if node_type == 'section':
            out.append("%sSection<%s>: %s" % (indent, node.id, node.title))
        elif node_type == 'resource':
            resource = node.resource
            out.append("%sContentNode<%s> -> %s<%s>: %s" % (indent, node.id, type(resource).__name__, resource.id, resource.name))
            for annotation in node.annotations.order_by('global_start_offset', 'id'):
                out.append("%s ContentAnnotation<%s>: %s %s-%s" % (indent, annotation.id, annotation.kind, annotation.global_start_offset, annotation.global_end_offset))
    return out


def dump_content_tree(node):
    """
        Return a nested list of the content_tree__children for this node, where each child is represented as
        [<child>, <child.content_tree__parent>, dump_content_tree(child)]
    """
    node.content_tree__load()
    return _dump_content_tree(node)


def _dump_content_tree(node):
    return [[child, child.content_tree__parent, _dump_content_tree(child)] for child in node.content_tree__children]


def dump_annotated_text(case_or_textblock):
    """
        Return an annotated Case or TextBlock as html with annotation [brackets]. Example:

        >>> annotations_factory, *_ = [getfixture(f) for f in ['annotations_factory']]
        >>> html = '<p>[replace]This[/replace] [highlight]is[/highlight] [elide]a[/elide] [note]case[/note].</p>'
        >>> casebook, case = annotations_factory('Case', html)
        >>> assert dump_annotated_text(case) == html
    """
    text_strs, offsets, tags = re_split_offsets(r'<[^>]+?>', case_or_textblock.content)
    to_insert = list(zip(offsets, tags))
    for annotation in case_or_textblock.related_annotations():
        to_insert.extend([
            (annotation.global_start_offset, '[%s]' % annotation.kind),
            (annotation.global_end_offset, '[/%s]' % annotation.kind),
        ])
    content = "".join(text_strs)
    for offset, text in sorted(to_insert, reverse=True):
        content = content[:offset] + text + content[offset:]
    return content
