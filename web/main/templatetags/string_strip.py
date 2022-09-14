from django import template

register = template.Library()


@register.filter
def string_strip(content: str, string_from: str) -> str:
    "Remove a substring."
    return content.replace(string_from, "")
