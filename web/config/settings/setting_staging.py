import os
import json
from .settings_base import *  # noqa

config = json.loads(os.environ.get("APP_CONFIG", "{}"))

DEBUG = False

AUTH_PASSWORD_VALIDATORS = []

RAILS_SECRET_KEY_BASE = config.get('RAILS_SECRET_KEY_BASE', '')
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST = config.get('EMAIL_HOST', '')
EMAIL_HOST_USER = config.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = config.get('EMAIL_HOST_PASSWORD', '')
ADMINS = config.get('ADMINS', [])
SERVER_EMAIL = config.get('SERVER_EMAIL', '')
USE_ANALYTICS = False
S3_STORAGE = {
    'access_key': config.get('AWS_ACCESS_KEY', ''),
    'secret_key': config.get('AWS_SECRET_KEY', '')
}
AWS_LAMBDA_EXPORT_SETTINGS = {
    'bucket_name': config.get('BUCKET_NAME', ''),
    'function_arn': config.get('FUNCTION_ARN', ''),
    'access_key': S3_STORAGE['access_key'],
    'secret_key': S3_STORAGE['secret_key']
}
FORCE_AWS_LAMBDA_EXPORT = True
USE_SENTRY = False
SENTRY_DSN = config.get('SENTRY_DSN', '')
SENTRY_ENVIRONMENT = 'staging'
SENTRY_TRACES_SAMPLE_RATE = 0.001