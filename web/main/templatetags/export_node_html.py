from django import template

from main.export import annotated_content_for_export
from main.models import ContentNode

register = template.Library()


@register.simple_tag
def export_node_html(node: ContentNode, export_options: dict = None, *args, **kwargs):
    return annotated_content_for_export(node, export_options)
