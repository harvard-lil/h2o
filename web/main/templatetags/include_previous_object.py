from django import template

register = template.Library()


@register.filter
def include_previous_object(iterable):
    """
    While iterating, yield both the current and the previous iteration's objects.
    Usage:
      {% for previous, current in 'abcd'|include_previous_object %}
        ({{ previous }}, {{ current }})
      {% endfor %}

      >> (None, a)(a, b)(b, c)(c, d)
    """
    previous = None
    for i in iterable:
        yield (previous, i)
        previous = i
