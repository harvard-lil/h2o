import json

from django.conf import settings as django_settings
from django.core.exceptions import ImproperlyConfigured
from django.urls import reverse
from django.utils.safestring import mark_safe

from main.models import Section, Casebook, Resource


def settings(request):
    """
    Adds the settings specified in settings.TEMPLATE_VISIBLE_SETTINGS to
    the request context.
    From https://github.com/mfogel/django-settings-context-processor/blob/master/settings_context_processor/context_processors.py
    """
    new_settings = {}
    for attr in getattr(django_settings, "TEMPLATE_VISIBLE_SETTINGS", ()):
        try:
            new_settings[attr] = getattr(django_settings, attr)
        except AttributeError:
            m = "TEMPLATE_VISIBLE_SETTINGS: '{0}' does not exist".format(attr)
            raise ImproperlyConfigured(m)
    return new_settings


_frontend_urls = None
def frontend_urls(request):
    """
        Our javascript needs a global dictionary of url templates like:

            FRONTEND_URLS = {
                'reorder_section_node': '/casebooks/_CASEBOOK_ID/sections/_SECTION_ORDINALS/reorder/_CHILD_ORDINALS/'
            }

        These can't be generated directly from reverse() because reverse('reorder_section_node', args=['_CASEBOOK_ID', ...])
        doesn't resolve -- we need to pass in args as ints or ordinals or Casebook instances or whatever.

        This function calls reverse() with valid inputs for each url template we need, and then replaces the strings
        in the resulting url with the desired placeholders.
    """
    global _frontend_urls
    if not _frontend_urls:
        urls_in = {
            # key: [url_name, reverse_args, strings, placeholders]
            'reorder_section_node': ['reorder_node', [1, "2", "3"], ["1", "2", "3"], ['_CASEBOOK_ID', '_SECTION_ORDINALS', '_CHILD_ORDINALS']],
            'reorder_casebook_node': ['reorder_node', [1, "2"], ["1", "2"], ['_CASEBOOK_ID', '_CHILD_ORDINALS']],
            'search': ['search', [], [], []],
            'new_casebook': ['new_casebook', [], [], []],
            'section': ['section', [1, "2"], ["1", "2"], ['CASEBOOK_ID', 'SECTION_ID']],
            'casebook': ['casebook', [1], ["1"], ['_ID']],
            'export_casebook': ['export', [Casebook(id=1), "docx"], ["1", "docx"], ['_ID', '_FORMAT']],
            'export_section': ['export', [Section(id=1), "docx"], ["1", "docx"], ['_ID', '_FORMAT']],
            'export_resource': ['export', [Resource(id=1), "docx"], ["1", "docx"], ['_ID', '_FORMAT']],
        }
        urls_out = {}
        for key, [url_name, reverse_args, strings, placeholders] in urls_in.items():
            url = reverse(url_name, args=reverse_args)
            for string, placeholder in zip(strings, placeholders):
                url = url.replace(str(string), placeholder, 1)
            urls_out[key] = url
        _frontend_urls = mark_safe(json.dumps(urls_out))
    return {'frontend_urls': _frontend_urls}
