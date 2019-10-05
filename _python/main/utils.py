import bleach
from django.conf import settings


def sanitize(html):
    """
    TODO: read up on this sanitization library
    """
    return bleach.clean(html, tags=['p', 'br', *bleach.sanitizer.ALLOWED_TAGS])


def show_debug_toolbar(request):
    """
        Whether to show the Django debug toolbar.
    """
    return bool(settings.DEBUG)
