from django import template
from django.utils.safestring import mark_safe
from main.sanitize import sanitize

register = template.Library()


@register.filter
def safe_headnote(value):
    return mark_safe(sanitize(value or ""))
