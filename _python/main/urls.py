from django.urls import path, re_path, register_converter
from rest_framework.urlpatterns import format_suffix_patterns

from . import views

#
# Converters
#

class IDSlugConverter:
    regex = '[0-9]+(\-.*)?'

    def to_python(self, value):
        l = value.split('-', 1)
        try:
            slug = l[1]
        except IndexError:
            slug = ''
        return {
            'id': int(l[0]),
            'slug': slug
        }

    def to_url(self, value):
        return '{}-{}'.format(value['id'], value['slug'])


class OrdinalSlugConverter:
    regex = '([0-9]+\.)*[0-9]+(\-.*)?'

    def to_python(self, value):
        l = value.split('-', 1)
        try:
            slug = l[1]
        except IndexError:
            slug = ''
        return {
            'ordinals': [int(i) for i in l[0].split('.')],
            'slug': slug
        }

    def to_url(self, value):
        ordinal_string = '.'.join(str(i) for i in value['ordinals'])
        return '{}-{}'.format(ordinal_string, value['slug'])


register_converter(IDSlugConverter, 'idslug')
register_converter(OrdinalSlugConverter, 'ordslug')


#
# URLs
#

# these patterns will have optional format suffixes added, like '.json'
drf_urlpatterns = [
    # annotations resource
    re_path(r'^resources/(?P<resource_id>\d+)/annotations$', views.annotations, name='annotations'),
]

urlpatterns = format_suffix_patterns(drf_urlpatterns) + [
    path('', views.index, name='index'),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:ordinals_param>/', views.section, name='section'),
    path('casebooks/<idslug:casebook_param>/', views.casebook, name='casebook'),
]
