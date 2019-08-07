from .settings_base import *  # noqa

ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]', '.local', 'backend']

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'k2#@_q=1$(__n7#(zax6#46fu)x=3&^lz&bwb8ol-_097k_rj5'

DEBUG = True

# don't check password quality locally, since it's annoying
AUTH_PASSWORD_VALIDATORS = []

if os.environ.get('DOCKERIZED'):
    DATABASES['default']['PASSWORD'] = 'password'
    DATABASES['default']['NAME'] = 'h2o_dev'


# avoid test errors when running tests locally, since pytest-django sets DEBUG=False and staticfiles/ doesn't exist
STATICFILES_STORAGE = 'pipeline.storage.PipelineStorage'
