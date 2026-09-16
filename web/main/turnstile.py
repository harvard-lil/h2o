"""Validate the on-demand browser check without granting application permissions."""

import requests
from django.conf import settings
from django.http import HttpResponse
from django.views.decorators.http import require_POST


@require_POST
def verify_browser(request):
    if not settings.TURNSTILE_SECRET_KEY:
        return HttpResponse(status=503)
    token = request.POST.get("token", "")
    if not token or len(token) > 2048:
        return HttpResponse(status=400)
    try:
        response = requests.post(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            data={"secret": settings.TURNSTILE_SECRET_KEY, "response": token},
            timeout=10,
        )
        response.raise_for_status()
        result = response.json()
    except requests.RequestException, ValueError:
        return HttpResponse(status=503)
    if (
        not isinstance(result, dict)
        or result.get("success") is not True
        or result.get("hostname") != request.get_host().split(":")[0]
        or result.get("action") != "api_preclearance"
    ):
        return HttpResponse(status=403)
    return HttpResponse(status=204)
