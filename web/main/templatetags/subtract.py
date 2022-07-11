from django import template

register = template.Library()


@register.filter
def subtract(x, y):
    return x - y
