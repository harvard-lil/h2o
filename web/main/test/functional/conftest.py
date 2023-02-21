import pytest
from django.core.management import call_command
from pytest_django.live_server_helper import LiveServer


@pytest.fixture(autouse=True, scope="function")
def load_fixtures(transactional_db, django_db_serialized_rollback):
    call_command(
        "loaddata",
        [
            "main/test/functional/fixtures/casebooks.json",
            "main/test/functional/fixtures/contentannotation.json",
            "main/test/functional/fixtures/contentcollaborators.json",
            "main/test/functional/fixtures/contentnodes.json",
            "main/test/functional/fixtures/textblocks.json",
            "main/test/functional/fixtures/users.json",
        ],
    )


# Ensure that staticfiles has been dropped from the app list before the live_server constructor runs.
# Implementation of this fix: https://github.com/pytest-dev/pytest-django/issues/294#issuecomment-1269236192
# This fixture be deleted when there's a better mechanism upstream to handle.
@pytest.fixture
def static_live_server(request, settings):
    if "django.contrib.staticfiles" in settings.INSTALLED_APPS:
        settings.INSTALLED_APPS.remove("django.contrib.staticfiles")
    server = LiveServer("localhost")
    request.addfinalizer(server.stop)
    return server


@pytest.fixture
def login_as_default(static_live_server, page):
    from main.test.functional.test_platform import login

    login(static_live_server, page)
