import urllib.parse
from django import template

register = template.Library()


@register.simple_tag(takes_context=True)
def current_query_string(context, **kwargs):
    """
        Given {% current_query_string page=1 q='' %}, return the current query string but with page and q values changed.
    """
    return urllib.parse.urlencode(dict(context['request'].GET, **kwargs), doseq=True)
