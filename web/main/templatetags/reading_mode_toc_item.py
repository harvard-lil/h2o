from django import template
from main.models import Casebook, ContentNode

register = template.Library()


@register.inclusion_tag("includes/reading_mode_toc_item.html")
def reading_mode_toc_item(toc: dict, casebook: Casebook, top_level_node: ContentNode):
    """
    Render one level of node in the reading mode TOC
    """

    return {"toc": toc, "casebook": casebook, "top_level_node": top_level_node}
