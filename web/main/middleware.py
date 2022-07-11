import logging
from datetime import timedelta

from django.contrib import auth
from django.contrib.auth.middleware import (
    AuthenticationMiddleware as DjangoAuthenticationMiddleware,
)
from django.utils import timezone
from django.utils.functional import SimpleLazyObject

from .utils import fix_after_rails


logger = logging.getLogger(__name__)

### auth middleware ###

# Auth middleware is based on django.contrib.auth.middleware.AuthenticationMiddleware, with additional
# handling once the user object is fetched:


def get_user(request):
    if not hasattr(request, "_cached_user"):
        user = request._cached_user = auth.get_user(request)

        # for authenticated users, set user.last_request_at to current datetime if not set within last 10 minutes:
        if user.is_authenticated:
            if not user.last_request_at or user.last_request_at < timezone.now() - timedelta(
                minutes=10
            ):
                user.last_request_at = timezone.now()
                user.save(update_fields=["last_request_at"])

    return request._cached_user


class AuthenticationMiddleware(DjangoAuthenticationMiddleware):
    def process_request(self, request):
        request.user = SimpleLazyObject(lambda: get_user(request))


### http-header-based method overriding ###

METHOD_OVERRIDE_HEADER = "HTTP_X_HTTP_METHOD_OVERRIDE"


def method_override_middleware(get_response):
    """
    Temporary middleware during migration to implement Rails-style HTTP method overriding,
    so that AJAX requests that are REALLY "POST", but include headers like
    "X-HTTP-Method-Override: PATCH" are treated as PATCH, PUT, DELETE, etc.
    https://www.django-rest-framework.org/topics/browser-enhancements/#http-header-based-method-overriding
    """
    fix_after_rails("update javascript to use http methods directly")

    def middleware(request):
        if request.method == "POST" and METHOD_OVERRIDE_HEADER in request.META:
            request.method = request.META[METHOD_OVERRIDE_HEADER].upper()
        return get_response(request)

    return middleware
