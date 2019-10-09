from rest_framework.response import Response


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

        >>> full_casebook = getfixture('full_casebook')
        >>> assert dump_casebook_outline(full_casebook) == [
        ...     'Casebook<1>: Some Title 0',
        ...     ' Section<2>: Some Section 1',
        ...     '  ContentNode<3> -> TextBlock<1>: Some TextBlock Name 0',
        ...     '  ContentNode<4> -> Case<1>: Foo Foo0 vs. Bar Bar0',
        ...     '   ContentAnnotation<1>: highlight 0-10',
        ...     '   ContentAnnotation<2>: elide 0-10',
        ...     '  ContentNode<5> -> Default<1>: Some Link Name 0',
        ...     '  ContentNode<6> -> TextBlock<2>: Some TextBlock Name 1',
        ...     '  ContentNode<7> -> Case<2>: Foo Foo1 vs. Bar Bar1',
        ...     '   ContentAnnotation<3>: note 0-10',
        ...     '   ContentAnnotation<4>: replace 0-10',
        ...     '  ContentNode<8> -> Default<2>: Some Link Name 1'
        ... ]
    """
    out = []
    out.append("Casebook<%s>: %s" % (casebook.id, casebook.title))
    for node in casebook.contents.prefetch_resources().prefetch_related('annotations').order_by('ordinals'):
        node_type = node.type
        indent = " " * len(node.ordinals)
        if node_type == 'section':
            out.append("%sSection<%s>: %s" % (indent, node.id, node.title))
        elif node_type == 'resource':
            resource = node.resource
            out.append("%sContentNode<%s> -> %s<%s>: %s" % (indent, node.id, type(resource).__name__, resource.id, resource.name))
            for annotation in node.annotations.all():
                out.append("%s ContentAnnotation<%s>: %s %s-%s" % (indent, annotation.id, annotation.kind, annotation.global_start_offset, annotation.global_end_offset))
    return out