"""
Tests for the H2O_SETTINGS_MODULE runtime settings selector in
config/settings/__init__.py.

These run config.settings in a *subprocess*, not in-process, because this test
process already imported config.settings.settings_pytest (which, as a side
effect of Python's package-import machinery, already ran
config/settings/__init__.py once and cached the result in sys.modules). A
fresh interpreter is the only reliable way to exercise the module-selection
logic under different environment variables. None of this touches a database:
importing a settings module only builds Python dicts/lists, it doesn't
connect to anything.
"""

import json
import os
import subprocess
import sys
import textwrap

import pytest

WEB_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# settings_aws_ecs reads all of these out of APP_CONFIG while it imports, so
# importing it at all means supplying them. The values are shaped only as far as
# that module and validate_settings() actually look: ALLOWED_HOSTS is split on
# commas, ADMINS is ast.literal_eval'd, FUNCTION_ARN is parsed into a region and
# a function name. A KeyError from here means settings_aws_ecs reads a new key
# and this dict needs it too.
FAKE_APP_CONFIG = {
    "ALLOWED_HOSTS": "example.test",
    "SECRET_KEY": "fake",
    "DATABASE_NAME": "postgres",
    "DATABASE_USERNAME": "postgres",
    "DATABASE_PASSWORD": "fake",
    "DATABASE_HOST": "db",
    "DATABASE_PORT": "5432",
    "CAPAPI_API_KEY": "fake",
    "GPO_API_KEY": "fake",
    "COURTLISTENER_API_KEY": "fake",
    "MATOMO_SITE_URL": "https://example.test/",
    "MATOMO_API_KEY": "fake",
    "MATOMO_SITE_ID": "3",
    "RAILS_SECRET_KEY_BASE": "fake",
    "EMAIL_HOST": "smtp.example.test",
    "EMAIL_HOST_USER": "fake",
    "EMAIL_HOST_PASSWORD": "fake",
    "ADMINS": "[('Someone', 'someone@example.test')]",
    "SERVER_EMAIL": "someone@example.test",
    "AWS_ACCESS_KEY": "fake",
    "AWS_SECRET_KEY": "fake",
    "BUCKET_NAME": "h2o.exports",
    "FUNCTION_ARN": "arn:aws:lambda:us-east-1:000000000000:function:fake",
    "TIER": "staging",
    "SENTRY_DSN": "",
}

# A developer may have their own config/settings/settings.py (gitignored). When it
# exists, the no-env-var path imports THAT rather than settings_dev, so the fallback
# test below can't assert anything about its contents. CI never has this file.
LOCAL_SETTINGS_PY = os.path.join(WEB_DIR, "config", "settings", "settings.py")


def _run(code, env_overrides):
    env = os.environ.copy()
    env.pop("H2O_SETTINGS_MODULE", None)
    env.pop("APP_CONFIG", None)
    env.update(env_overrides)
    return subprocess.run(
        [sys.executable, "-c", textwrap.dedent(code)],
        cwd=WEB_DIR,
        env=env,
        capture_output=True,
        text=True,
    )


def _installed_apps(settings_module, env_overrides=None):
    env = {"H2O_SETTINGS_MODULE": settings_module}
    env.update(env_overrides or {})
    result = _run(
        """
        import json
        import config.settings as settings
        print(json.dumps(list(settings.INSTALLED_APPS)))
        """,
        env,
    )
    assert result.returncode == 0, result.stderr
    # settings_base prints to stdout when it can't find its ALI materials, so
    # take the last line rather than the whole of stdout.
    return json.loads(result.stdout.splitlines()[-1])


def test_settings_build_installed_apps_match_the_deployed_ones():
    # The image build runs collectstatic and migration_manifest under
    # settings_build, and both commands derive their whole output from
    # INSTALLED_APPS. What they bake into the image describes the deployed app
    # only for as long as the two lists agree.
    assert _installed_apps("settings_build") == _installed_apps(
        "settings_aws_ecs", {"APP_CONFIG": json.dumps(FAKE_APP_CONFIG)}
    )


def test_h2o_settings_module_selects_named_module():
    result = _run(
        """
        import config.settings as settings
        assert settings.DEBUG is False, settings.DEBUG
        print("ok")
        """,
        {"H2O_SETTINGS_MODULE": "settings_prod"},
    )
    assert result.returncode == 0, result.stderr
    assert "ok" in result.stdout


def test_h2o_settings_module_only_merges_uppercase_names():
    # settings_prod does `from .settings_base import *`, which pulls in settings_base's
    # own lowercase/mixed-case imports (e.g. `TypedDict`) along with real settings. Only
    # the real (uppercase) settings should end up on config.settings.
    result = _run(
        """
        import config.settings as settings
        assert hasattr(settings, "BASE_DIR")
        assert not hasattr(settings, "TypedDict")
        print("ok")
        """,
        {"H2O_SETTINGS_MODULE": "settings_prod"},
    )
    assert result.returncode == 0, result.stderr
    assert "ok" in result.stdout


def test_h2o_settings_module_unknown_name_raises_clear_error():
    result = _run(
        "import config.settings",
        {"H2O_SETTINGS_MODULE": "settings_does_not_exist"},
    )
    assert result.returncode != 0
    assert "ImportError" in result.stderr
    assert "H2O_SETTINGS_MODULE" in result.stderr
    assert "settings_does_not_exist" in result.stderr
    # Must fail loudly, not silently boot with dev settings.
    assert "does not name a module" in result.stderr


def test_h2o_settings_module_internal_error_is_not_misreported_as_unknown_module():
    # settings_aws_ecs.py exists, but requires an APP_CONFIG env var to import. That
    # failure is a real configuration problem in an existing module, not a typo'd
    # module name, so it must surface as-is rather than as our "unknown module" error.
    result = _run(
        "import config.settings",
        {"H2O_SETTINGS_MODULE": "settings_aws_ecs"},
    )
    assert result.returncode != 0
    assert "KeyError" in result.stderr
    assert "APP_CONFIG" in result.stderr
    assert "does not name a module" not in result.stderr


@pytest.mark.skipif(
    os.path.exists(LOCAL_SETTINGS_PY),
    reason="local config/settings/settings.py shadows the settings_dev fallback",
)
def test_h2o_settings_module_unset_falls_back_to_settings_dev():
    result = _run(
        """
        import config.settings as settings
        assert settings.DEBUG is True
        print("ok")
        """,
        {},
    )
    assert result.returncode == 0, result.stderr
    assert "ok" in result.stdout
