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
# fix_before_deploy('Where does this logfile want to live?')
# LOGGING['handlers']['file']['filename'] = '/var/log/h2o.log'

# fix_before_deploy('We need to set up email.')
# EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
# EMAIL_PORT = 587
# EMAIL_USE_TLS = True
# EMAIL_HOST = 'smtp.example.com'
# EMAIL_HOST_USER = 'smtpuser'
# EMAIL_HOST_PASSWORD = 'smtppw'
