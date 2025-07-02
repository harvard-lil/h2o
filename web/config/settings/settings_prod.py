import os
import json
from .settings_base import *  # noqa

config = json.loads(os.environ["APP_CONFIG"])

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

ALLOWED_HOSTS = config["ALLOWED_HOSTS"].split(",")
SECRET_KEY = config["SECRET_KEY"]
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": config["DATABASE_NAME"],
        "USER": config["DATABASE_USERNAME"],
        "PASSWORD": config["DATABASE_PASSWORD"],
        "HOST": config["DATABASE_HOST"],
        "PORT": config["DATABASE_PORT"],
    }
}
CAPAPI_API_KEY = config["CAPAPI_API_KEY"]
GPO_API_KEY = config["GPO_API_KEY"]
COURTLISTENER_API_KEY = config["COURTLISTENER_API_KEY"]
MATOMO_SITE_URL = config["MATOMO_SITE_URL"]
MATOMO_API_KEY = config["MATOMO_API_KEY"]
MATOMO_SITE_ID = config["MATOMO_SITE_ID"]
RAILS_SECRET_KEY_BASE = config["RAILS_SECRET_KEY_BASE"]
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST = config["EMAIL_HOST"]
EMAIL_HOST_USER = config["EMAIL_HOST_USER"]
EMAIL_HOST_PASSWORD = config["EMAIL_HOST_PASSWORD"]
ADMINS = config["ADMINS"]
SERVER_EMAIL = config["SERVER_EMAIL"]
USE_ANALYTICS = True
S3_STORAGE = {
    "access_key": config["AWS_ACCESS_KEY"],
    "secret_key": config["AWS_SECRET_KEY"],
}
AWS_LAMBDA_EXPORT_SETTINGS = {
    "bucket_name": config["BUCKET_NAME"],
    "function_arn": config["FUNCTION_ARN"],
    "access_key": S3_STORAGE["access_key"],
    "secret_key": S3_STORAGE["secret_key"],
}
FORCE_AWS_LAMBDA_EXPORT = True
USE_SENTRY = config["TIER"] == "prod"
SENTRY_DSN = config["SENTRY_DSN"]
SENTRY_ENVIRONMENT = config["TIER"]
SENTRY_TRACES_SAMPLE_RATE = 0.001
