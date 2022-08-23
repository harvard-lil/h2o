import os
import sys

from .settings_base import *  # noqa


ALLOWED_HOSTS = ["opencasebook.test", "localhost", "127.0.0.1", "[::1]"]

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = "k2#@_q=1$(__n7#(zax6#46fu)x=3&^lz&bwb8ol-_097k_rj5"

# Set these values in your local shell environment to make them available in the container
CAPAPI_API_KEY = os.environ.get("CAPAPI_API_KEY", "")
GPO_API_KEY = os.environ.get("GPO_API_KEY", "")
MATOMO_API_KEY = os.environ.get("MATOMO_API_KEY", "")
MATOMO_SITE_URL = os.environ.get("MATOMO_SITE_URL", "")

DEBUG = True

# don't check password quality locally, since it's annoying
AUTH_PASSWORD_VALIDATORS = []

# avoid test errors when running tests locally, since pytest-django sets DEBUG=False and staticfiles/ doesn't exist
# STATICFILES_STORAGE = 'pipeline.storage.PipelineStorage'

# django-debug-toolbar:
# See the README for current instructions on running with django debug toolbar enabled

if "pytest" not in sys.modules:  # don't run this from tests
    if os.environ.get("DEBUG_TOOLBAR"):
        INSTALLED_APPS += ("debug_toolbar",)
        MIDDLEWARE.insert(0, "debug_toolbar.middleware.DebugToolbarMiddleware")
        INTERNAL_IPS = ["127.0.0.1"]
        DEBUG_TOOLBAR_CONFIG = {"SHOW_TOOLBAR_CALLBACK": "main.utils.show_debug_toolbar"}

# Print sent emails to the console, for debugging
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# For testing error reporting
ADMINS = [("John", "john@example.com"), ("Mary", "mary@example.com")]

LOGGING["loggers"]["main"] = {"level": "DEBUG", "handlers": ["console", "file"]}

WEBPACK_LOADER = {
    "DEFAULT": {
        "BUNDLE_DIR_NAME": "dist/",
        "STATS_FILE": os.path.join(BASE_DIR, ".webpack-stats-dev.json"),
    }
}
