from .settings_base import *  # noqa

ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]', '.local', 'backend', 'django']

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'k2#@_q=1$(__n7#(zax6#46fu)x=3&^lz&bwb8ol-_097k_rj5'

DEBUG = True

# don't check password quality locally, since it's annoying
AUTH_PASSWORD_VALIDATORS = []

# avoid test errors when running tests locally, since pytest-django sets DEBUG=False and staticfiles/ doesn't exist
# STATICFILES_STORAGE = 'pipeline.storage.PipelineStorage'

# django-debug-toolbar:
# ddt can be useful but also be a hassle, so it only runs optionally, if you choose to `pip install django-debug-toolbar`
# If installed, there will be a sidebar when viewing front-end pages, including useful tools such as a SQL profiler.
import sys
if 'pytest' not in sys.modules:  # don't run this from tests
    try:
        import debug_toolbar  # noqa
        if 'debug_toolbar' not in INSTALLED_APPS:
            INSTALLED_APPS += (
                'debug_toolbar',
            )
            MIDDLEWARE.insert(0, 'debug_toolbar.middleware.DebugToolbarMiddleware')
            INTERNAL_IPS = ['127.0.0.1']
            DEBUG_TOOLBAR_CONFIG = {
                'SHOW_TOOLBAR_CALLBACK': 'main.utils.show_debug_toolbar'
            }
    except ImportError:
        pass

# Print sent emails to the console, for debugging
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# For testing error reporting
ADMINS = [('John', 'john@example.com'), ('Mary', 'mary@example.com')]

LOGGING['loggers']['main'] = {
    'level': 'DEBUG',
    'handlers': ['console', 'file']
}

ENABLE_PRINTABLE_HTML = True