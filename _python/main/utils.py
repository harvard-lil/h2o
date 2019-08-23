import bleach
import django.core.paginator


def sanitize(html):
    """
    TODO: read up on this sanitization library
    """
    return bleach.clean(html, tags=['p', 'br', *bleach.sanitizer.ALLOWED_TAGS])


class Paginator(django.core.paginator.Paginator):
    @property
    def short_page_range(self):
        return (i for i in self.page_range if i <= 2 or i >= self.num_pages-1 or abs(i-self.num_pages))
        page_range = self.page_range
