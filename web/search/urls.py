from django.urls import path

from . import views

urlpatterns = [
    path('', views.search, name='search'),
    path('cases/', views.search_cases, name='search_cases'),
]
