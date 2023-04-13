from . import views

from django.urls import path

urlpatterns = [path("stats/", views.matomo_stats, name="matomo-stats")]
