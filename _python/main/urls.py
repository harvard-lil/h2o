from django.urls import path, re_path, register_converter
from django.views.generic import RedirectView, TemplateView
from rest_framework.urlpatterns import format_suffix_patterns

from . import views


#
# Converters
#

class IdSlugConverter:
    # matches:
    # 2, 2-, 22-slug, etc.
    regex = r'[0-9]+(\-[^/]*)?'

    def to_python(self, value):
        id_slug = value.split('-', 1)
        try:
            slug = id_slug[1]
        except IndexError:
            slug = ''
        return {
            'id': int(id_slug[0]),
            'slug': slug
        }

    def to_url(self, value):
        if isinstance(value, int):
            return str(value)
        slug = value.get('slug')
        if slug:
            return '{}-{}'.format(value['id'], value.get('slug'))
        return str(value['id'])


class OrdinalSlugConverter:
    # matches:
    # 2, 2.2, 22.2.22, 2-, 2-slug, 2.22.2-, 2.2.22-slug, etc.
    regex = r'([0-9]+\.)*[0-9]+(\-[^/]*)?'

    def to_python(self, value):
        ord_slug = value.split('-', 1)
        try:
            slug = ord_slug[1]
        except IndexError:
            slug = ''
        return {
            'ordinals': [int(i) for i in ord_slug[0].split('.')],
            'slug': slug
        }

    def to_url(self, value):
        ordinal_string = '.'.join(str(i) for i in value['ordinals'])
        slug = value.get('slug')
        if slug:
            return '{}-{}'.format(ordinal_string, slug)
        return ordinal_string


register_converter(IdSlugConverter, 'idslug')
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
    path('users/<int:user_id>/', views.dashboard, name='dashboard'),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:ordinals_param>/', views.resource, name='resource'),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:ordinals_param>/', views.section, name='section'),
    path('casebooks/<idslug:casebook_param>/', views.casebook, name='casebook'),
    path('cases/from_capapi', views.from_capapi, name='from_capapi'),
    path('cases/<int:case_id>/', views.case, name='case'),
    # canonical paths for static pages
    path('about/', TemplateView.as_view(template_name='pages/about.html'), name='about'),
    path('privacy-policy/', TemplateView.as_view(template_name='pages/privacy-policy.html'), name='privacy-policy'),
    path('terms-of-service/', TemplateView.as_view(template_name='pages/terms-of-service.html'), name='terms-of-service'),
    path('faq/', TemplateView.as_view(template_name='pages/faq.html'), name='faq'),
    # legacy paths for static pages
    path('pages/about/', RedirectView.as_view(pattern_name='about', permanent=True)),
    path('pages/privacy-policy/', RedirectView.as_view(pattern_name='privacy-policy', permanent=True)),
    path('pages/terms-of-service/', RedirectView.as_view(pattern_name='terms-of-service', permanent=True)),
    path('pages/faq/', RedirectView.as_view(pattern_name='faq', permanent=True)),
]
