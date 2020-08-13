# Django settings used by pytest

# WARNING: this imports from .settings_dev instead of config.settings, meaning it chooses to IGNORE any settings in
# config/settings/settings.py. This is potentially better (in that it doesn't return different results locally than
# it will on CI), but also potentially worse (in that you can't try out settings tweaks in settings.py and run tests
# against them).

from .settings_dev import *

TESTING = True

# Don't use whitenoise for tests. Including whitenoise causes it to rescan static during each test, which greatly
# increases test time.
MIDDLEWARE.remove('whitenoise.middleware.WhiteNoiseMiddleware')

CAPAPI_API_KEY = '12345'

LOGGING['loggers']['django']['handlers'].append('mail_admins')
