from django.urls import path, re_path, register_converter
from django.views.generic import RedirectView, TemplateView
from rest_framework.urlpatterns import format_suffix_patterns

from .utils import fix_after_rails
from .models import Casebook, Section
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

    @staticmethod
    def to_url(value):
        """
            >>> assert IdSlugConverter.to_url(1) == "1"
            >>> assert IdSlugConverter.to_url({"id": 1}) == "1"
            >>> assert IdSlugConverter.to_url({"id": 1, "slug": "foo"}) == "1-foo"
            >>> assert IdSlugConverter.to_url(Casebook(id=1, title="foo")) == "1-foo"
        """
        if hasattr(value, 'id'):
            id = value.id
            slug = value.get_slug()
        elif isinstance(value, int):
            id = value
            slug = None
        elif isinstance(value, dict):
            id = value['id']
            slug = value.get('slug')
        else:
            raise ValueError("Cannot create IdSlug from argument type %s" % type(value))
        return str(id) + (("-%s" % slug) if slug else "")


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

    @staticmethod
    def to_url(value):
        """
            >>> assert OrdinalSlugConverter.to_url({"ordinals": [1, 2]}) == "1.2"
            >>> assert OrdinalSlugConverter.to_url({"ordinals": [1, 2], "slug": "foo"}) == "1.2-foo"
            >>> assert OrdinalSlugConverter.to_url(Section(ordinals=[1, 2], title="foo")) == "1.2-foo"
        """
        if hasattr(value, 'ordinals'):
            ordinals = value.ordinals
            slug = value.get_slug()
        elif isinstance(value, dict):
            ordinals = value['ordinals']
            slug = value.get('slug')
        else:
            raise ValueError("Cannot create OrdinalSlug from argument type %s" % type(value))
        return '.'.join(str(i) for i in ordinals) + (("-%s" % slug) if slug else "")


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
    # resources
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/layout/', RedirectView.as_view(pattern_name='resource', permanent=True)),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/edit/', views.edit_resource, name='edit_resource'),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/annotate/', views.annotate_resource, name='annotate_resource'),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/', views.resource, name='resource'),
    # sections
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/layout/', views.edit_section, name='edit_section'),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/edit/', RedirectView.as_view(pattern_name='edit_section', permanent=True)),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/', views.section, name='section'),
    # reordering nodes
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/reorder/<ordslug:node_param>', views.reorder_node, name='reorder_node'),
    path('casebooks/<idslug:casebook_param>/reorder/<ordslug:node_param>', views.reorder_node, name='reorder_node'),
    # casebooks
    path('casebooks/<idslug:casebook_param>/layout/', views.edit_casebook, name='edit_casebook'),
    path('casebooks/<idslug:casebook_param>/edit/', RedirectView.as_view(pattern_name='edit_casebook', permanent=True)),
    path('casebooks/<idslug:casebook_param>/clone/', views.clone_casebook, name='clone'),
    path('casebooks/<idslug:casebook_param>/create_draft/', views.create_draft, name='create_draft'),
    # TODO: we temporarily need to list with and without trailing slash, to handle POSTs without slashes
    path('casebooks/<idslug:casebook_param>/', views.CasebookView.as_view(), name='casebook'),
    path('casebooks/<idslug:casebook_param>', views.CasebookView.as_view(), name='casebook'),
    # cases
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
fix_after_rails("some routes don't have end slashes for rails compatibility")
