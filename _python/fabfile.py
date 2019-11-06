import os
from functools import wraps

import django
from fabric.api import local
from fabric.decorators import task

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

_django_setup = False
def setup_django(func):
    """
        For speed, avoid setting up django until we need it. Attach @setup_django to any tasks that rely on importing django packages.
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        global _django_setup
        if not _django_setup:
            django.setup()
            _django_setup = True
        return func(*args, **kwargs)
    return func


@task(alias='run')
def run_django(port=None):
    if port is None:
        port = "0.0.0.0:8000" if os.environ.get('DOCKERIZED') else "127.0.0.1:8000"
    local('python manage.py runserver %s' % port)