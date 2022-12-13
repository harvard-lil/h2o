from typing import Optional
from django import template
from main.models import Casebook

register = template.Library()


@register.inclusion_tag("includes/featured_casebook.html")
def featured_casebook(
    id: int,
    title: Optional[str] = None,
    authors: Optional[str] = None,
    cover_image: Optional[str] = None,
):
    """
    Render a casebook on the Featured Casebooks page, optionally overriding metadata on the casebook object itself
    """
    casebook = Casebook.objects.filter(id=id).first()

    if not casebook:
        return {"error": f"Casebook ID {id} was not found in this environment"}

    if not casebook.is_public:
        return {"error": f"Casebook ID {id} is not publicly viewable"}

    return {
        "casebook": casebook,
        "title": title or casebook.title,
        "authors": [{"display_name": authors}]
        if authors
        else [author for author in casebook.primary_authors if author.verified_professor],
        "cover_image": cover_image,
        "error": None,
    }
