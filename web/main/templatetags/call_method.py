from django import template

register = template.Library()


@register.simple_tag
def call_method(obj, method, *args, **kwargs):
    """
    Call a method on an object and return the result. Example:

        {% call_method casebook has_collaborator request.user as has_collaborator %}

    Useful for migrating Rails templates that have assignment statements at the top.
    """
    return getattr(obj, method)(*args, **kwargs)
