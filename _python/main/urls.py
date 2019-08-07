from django.urls import path, re_path
from rest_framework.urlpatterns import format_suffix_patterns

from . import views

# these patterns will have optional format suffixes added, like '.json'
drf_urlpatterns = [
    # annotations resource
    re_path(r'^resources/(?P<resource_id>\d+)/annotations$', views.annotations, name='annotations'),
]

urlpatterns = format_suffix_patterns(drf_urlpatterns) + [
    path('', views.index, name='index'),
    path('casebooks/<int:casebook_id>/', views.casebook, name='casebook')
]
