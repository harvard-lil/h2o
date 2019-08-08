import bleach

def sanitize(html):
    """
    TODO: read up on this sanitization library
    """
    return bleach.clean(html, tags=['p', *bleach.sanitizer.ALLOWED_TAGS])
