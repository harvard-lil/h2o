from .settings_base import *  # noqa

DEBUG = False

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# logging
LOGGING['loggers'] = {
    'django': {
        'handlers': ['file', 'mail_admins'],
        'level': 'INFO',
        'propagate': True,
    },
    'django.request': {
        'handlers': ['mail_admins'],
        'level': 'ERROR',
        'propagate': False,
    },
}
