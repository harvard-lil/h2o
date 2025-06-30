import os
import json
from .settings_base import *  # noqa

config = json.loads(os.environ.get("APP_CONFIG", "{}"))

DEBUG = False

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# logging
LOGGING["loggers"] = {
    "django": {
        "handlers": ["file", "mail_admins"],
        "level": "INFO",
        "propagate": True,
    },
    "django.request": {
        "handlers": ["mail_admins"],
        "level": "ERROR",
        "propagate": False,
    },
}


RAILS_SECRET_KEY_BASE = config.get("RAILS_SECRET_KEY_BASE", "")
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST = config.get("EMAIL_HOST", "")
EMAIL_HOST_USER = config.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = config.get("EMAIL_HOST_PASSWORD", "")
ADMINS = config.get("ADMINS", [])
SERVER_EMAIL = config.get("SERVER_EMAIL", "")
USE_ANALYTICS = True
S3_STORAGE = {
    "access_key": config.get("AWS_ACCESS_KEY", ""),
    "secret_key": config.get("AWS_SECRET_KEY", ""),
}
AWS_LAMBDA_EXPORT_SETTINGS = {
    "bucket_name": config.get("BUCKET_NAME", ""),
    "function_arn": config.get("FUNCTION_ARN", ""),
    "access_key": S3_STORAGE["access_key"],
    "secret_key": S3_STORAGE["secret_key"],
}
FORCE_AWS_LAMBDA_EXPORT = True
USE_SENTRY = True
SENTRY_DSN = config.get("SENTRY_DSN", "")
SENTRY_ENVIRONMENT = "prod"
SENTRY_TRACES_SAMPLE_RATE = 0.001
