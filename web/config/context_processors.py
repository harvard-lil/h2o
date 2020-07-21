import json

from django.conf import settings as django_settings
from django.core.exceptions import ImproperlyConfigured
from django.utils.safestring import mark_safe
from main.urls import urlpatterns


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
    def munge_url(urlpat):
        type_trailer = '<drf_format_suffix:format>'
        url = urlpat.pattern.describe().split("'")[1].replace(type_trailer, '.json')
        replacements =  {'<idslug:casebook_param>'     : '_casebookId',
                         '<ordslug:resource_param>'    : '_resourceOrd',
                         '<ordslug:section_param>'     : '_sectionOrd',
                         '<ordslug:node_param>'        : '_nodeOrd',
                         '<int:case_id>'               : '_caseId',
                         '<casebook:node>'             : '_casebookId',
                         '<section:node>'              : '_sectionId',
                         '<resource:node>'             : '_resourceId',
                         '<resource:resource>'         : '_resourceId',
                         '<idslug:from_casebook_dict>' : '_fromCasebookId',
                         '<ordslug:from_section_dict>' : '_fromSectionOrd',
                         '<idslug:to_casebook_dict>'   : '_toCasebookId',
                         '<idslug:section_id>'         : '_sectionId',
                         '<annotation:annotation>.json': '_annotationId',
                         '<idslug:section_id>.json'    : '_sectionId'
        }
        return [replacements.get(x,x) for x in url.split('/')]
    global _frontend_urls
    if not _frontend_urls:
        filtered_names = set([None, 'password_reset', 'password_reset_confirm', 'dashboard', 'export'])
        _frontend_urls = {u.pattern.name:munge_url(u)  for u in urlpatterns if u.pattern.name not in filtered_names}
    return {'frontend_urls': mark_safe(json.dumps(_frontend_urls))}
