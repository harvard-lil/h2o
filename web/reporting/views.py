import dataclasses

from django.http import HttpRequest, JsonResponse

from reporting.matomo import usage
from .admin.usage_dashboard import DateForm


def matomo_stats(request: HttpRequest):
    """When requested as on page load, retrieve Matomo analytics for the given time period"""
    form = DateForm(request.GET)
    if form.is_valid():
        web_usage = usage(
            form.cleaned_data["start_date"],
            form.cleaned_data["end_date"],
            form.cleaned_data["published"],
        )
        return JsonResponse(dataclasses.asdict(web_usage))
    return JsonResponse("")
