from django.urls import path, re_path, register_converter
from rest_framework.urlpatterns import format_suffix_patterns

from . import views

#
# Converters
#

class OrdinalsConverter:
    regex = '([0-9]+\.)*[0-9]+'

    def to_python(self, value):
        return [int(i) for i in value.split('.')]

    def to_url(self, value):
        return '.'.join(str(i) for i in value)

register_converter(OrdinalsConverter, 'ord')


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
    path('casebooks/<str:casebook_param>', views.casebook, name='casebook')
    path('casebooks/<int:casebook_id>/sections/<ord:ordinals>/', views.section, name='section'),
]
