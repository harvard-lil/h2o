from django.contrib.auth import views as auth_views
from django.urls import path, register_converter, include
from django.views.generic import RedirectView, TemplateView
from rest_framework.urlpatterns import format_suffix_patterns

from .models import Casebook, Section, ContentNode, ContentAnnotation
from .test.test_permissions_helpers import no_perms_test
from .url_converters import IdSlugConverter, OrdinalSlugConverter, register_model_converter
from .utils import fix_after_rails
from . import views, forms


register_converter(IdSlugConverter, 'idslug')
register_converter(OrdinalSlugConverter, 'ordslug')
register_model_converter(Casebook)
register_model_converter(Section)
register_model_converter(ContentNode, 'resource')
register_model_converter(ContentAnnotation, 'annotation')

# these patterns will have optional format suffixes added, like '.json'
drf_urlpatterns = [
    # annotations
    path('resources/<resource:resource>/annotations/<annotation:annotation>', views.AnnotationDetailView.as_view(), name='annotation_detail'),
    path('resources/<resource:resource>/annotations', views.AnnotationListView.as_view(), name='annotation_list'),
    path('casebook/<idslug:casebook_param>/toc/<idslug:section_id>', views.SectionTOCView.as_view(), name='toc_list'),
    path('casebook/<idslug:casebook_param>/toc', views.CasebookTOCView.as_view(), name='casebook_toc_list'),
]

urlpatterns = format_suffix_patterns(drf_urlpatterns) + [
    path('', views.index, name='index'),
    path('archived/', views.archived_casebooks, name='archived_casebooks'),

    # users
    path('users/<int:user_id>/', views.dashboard, name='dashboard'),
    path('accounts/new/', views.sign_up, name='sign_up'),
    path('accounts/edit/', views.edit_user, name='edit_user'),
    # built-in Django auth views for login/logout/password update/password reset, with overrides to replace the form or tweak behavior in some views
    path('accounts/password_reset/', no_perms_test(views.reset_password), name='password_reset'),
    path('accounts/reset/<uidb64>/<token>/', no_perms_test(auth_views.PasswordResetConfirmView.as_view(form_class=forms.SetPasswordForm)), name='password_reset_confirm'),
    path('accounts/', include('django.contrib.auth.urls')),

    # resources
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/layout/', RedirectView.as_view(pattern_name='resource', permanent=True)),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/edit/', views.edit_resource, name='edit_resource'),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/annotate/', views.annotate_resource, name='annotate_resource'),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>/', views.ResourceView.as_view(), name='resource'),
    path('casebooks/<idslug:casebook_param>/resources/<ordslug:resource_param>', no_perms_test(views.ResourceView.as_view())),
    # sections
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/layout/', views.edit_section, name='edit_section'),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/edit/', RedirectView.as_view(pattern_name='edit_section', permanent=True)),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/', views.SectionView.as_view(), name='section'),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>', no_perms_test(views.SectionView.as_view())),
    # sections and resources
    path('casebooks/<idslug:casebook_param>/sections', views.new_section_or_resource, name='new_section_or_resource'),
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/credits/', views.show_credits, name='show_resource_credits'),
    # reordering nodes
    path('casebooks/<idslug:casebook_param>/sections/<ordslug:section_param>/reorder/<ordslug:node_param>', views.reorder_node, name='reorder_node'),
    path('casebooks/<idslug:casebook_param>/reorder/<ordslug:node_param>', views.reorder_node, name='reorder_node'),
    # casebooks
    path('casebooks/<idslug:casebook_param>/layout/', views.edit_casebook, name='edit_casebook'),
    path('casebooks/<idslug:casebook_param>/edit/', RedirectView.as_view(pattern_name='edit_casebook', permanent=True)),
    path('casebooks/<idslug:casebook_param>/clone/', views.clone_casebook, name='clone'),
    path('casebooks/<idslug:from_casebook_dict>/sections/<ordslug:from_section_dict>/clone/to/<idslug:to_casebook_dict>/', views.clone_casebook_nodes, name='clone_nodes'),
    path('casebooks/<idslug:casebook_param>/create_draft/', views.create_draft, name='create_draft'),
    path('casebooks/<idslug:casebook_param>/credits/', views.show_credits, name='show_credits'),
    path('casebooks/<idslug:casebook_param>/settings/', views.casebook_settings, name='casebook_settings'),

    # TODO: we temporarily need to list with and without trailing slash, to handle POSTs without slashes
    path('casebooks/<idslug:casebook_param>/', views.CasebookView.as_view(), name='casebook'),
    path('casebooks/<idslug:casebook_param>', no_perms_test(views.CasebookView.as_view())),
    path('casebooks/new', views.new_casebook, name='new_casebook'),
    # cases
    path('cases/from_capapi', views.from_capapi, name='from_capapi'),
    path('cases/<int:case_id>/', views.case, name='case'),
    # export
    path('casebooks/<casebook:node>/export.<file_type>', views.export, name='export'),
    path('sections/<section:node>/export.<file_type>', views.export, name='export'),
    path('resources/<resource:node>/export.<file_type>', views.export, name='export'),
    # canonical paths for static pages
    path('pages/about/', TemplateView.as_view(template_name='pages/about.html'), name='about'),
    path('pages/privacy-policy/', TemplateView.as_view(template_name='pages/privacy-policy.html'), name='privacy-policy'),
    path('pages/terms-of-service/', TemplateView.as_view(template_name='pages/terms-of-service.html'), name='terms-of-service'),
    path('pages/faq/', TemplateView.as_view(template_name='pages/faq.html'), name='faq'),
    path('robots.txt', TemplateView.as_view(template_name='robots.txt'), name='robots_txt'),
    # TODO: remove pages/ from the above URLs and use these redirects
    # path('pages/about/', RedirectView.as_view(pattern_name='about', permanent=True)),
    # path('pages/privacy-policy/', RedirectView.as_view(pattern_name='privacy-policy', permanent=True)),
    # path('pages/terms-of-service/', RedirectView.as_view(pattern_name='terms-of-service', permanent=True)),
    # path('pages/faq/', RedirectView.as_view(pattern_name='faq', permanent=True)),
]
fix_after_rails("some routes don't have end slashes for rails compatibility")
fix_after_rails("remove pages/ from static pages URLs")
