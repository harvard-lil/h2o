import os
import sys
import json
from .settings_base import *  # noqa

config = json.loads(os.environ.get("APP_CONFIG", "{}"))

DEBUG = True

# don't check password quality locally, since it's annoying
AUTH_PASSWORD_VALIDATORS = []

# avoid test errors when running tests locally, since pytest-django sets DEBUG=False and staticfiles/ doesn't exist
# STATICFILES_STORAGE = 'pipeline.storage.PipelineStorage'

# django-debug-toolbar:
# See the README for current instructions on running with django debug toolbar enabled

if "pytest" not in sys.modules:  # don't run this from tests
    if config.get("DEBUG_TOOLBAR"):
        INSTALLED_APPS += ("debug_toolbar",)
        MIDDLEWARE.insert(0, "debug_toolbar.middleware.DebugToolbarMiddleware")
        INTERNAL_IPS = ["127.0.0.1"]
        DEBUG_TOOLBAR_CONFIG = {"SHOW_TOOLBAR_CALLBACK": "main.utils.show_debug_toolbar"}

# Print sent emails to the console, for debugging
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# For testing error reporting
ADMINS = [("John", "john@example.com"), ("Mary", "mary@example.com")]

LOGGING["loggers"]["main"] = {"level": "DEBUG", "handlers": ["console", "file"]}
