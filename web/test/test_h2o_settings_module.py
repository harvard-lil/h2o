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

import os
import subprocess
import sys
import textwrap

import pytest

WEB_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
