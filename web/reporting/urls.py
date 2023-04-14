from django.urls import path

from . import views

urlpatterns = [
    path("stats/", views.matomo_stats, name="matomo-stats"),
    path("time-series/casebooks", views.casebook_timeseries, name="reporting-casebook-timeseries"),
]
