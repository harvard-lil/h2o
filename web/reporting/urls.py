from django.urls import path

from . import views

urlpatterns = [
    path("stats/", views.matomo_stats, name="matomo-stats"),
    path(
        "time-series/professor-casebooks",
        views.professor_casebook_timeseries,
        name="reporting-professor-casebook-timeseries",
    ),
    path(
        "time-series/casebooks",
        views.casebook_timeseries,
        name="reporting-casebook-timeseries",
    ),
]
