# This is the base module that will be imported by Django.
#
# There are two ways to choose which deployment settings apply. Whichever one
# supplies settings here, everything below this point (Sentry setup and
# validate_settings()) still runs -- that's the point of Django importing this
# package rather than one of its submodules directly.
#
# 1. H2O_SETTINGS_MODULE environment variable, read at runtime. Set it to the
#    name of a sibling module in this package, e.g. "settings_aws_ecs" or
#    "settings_prod". This lets one built image boot as any deployment target
#    without baking a settings.py into it at build time. Takes precedence
#    over settings.py below when set.
# 2. config/settings/settings.py, resolved at import time with no env var
#    needed. Copy settings.py.example to settings.py and edit it; it in turn
#    imports one of the deployment targets. This is for a developer's local
#    checkout. If settings.py doesn't exist, we assume this is a vanilla
#    development environment and import .settings_dev instead.
import importlib
import os

_h2o_settings_module = os.environ.get("H2O_SETTINGS_MODULE")

if _h2o_settings_module:
    if not _h2o_settings_module.isidentifier():
        raise ImportError(
            f"H2O_SETTINGS_MODULE={_h2o_settings_module!r} is not a valid module name. "
            "Set it to the name of a sibling module in config/settings, e.g. "
            "'settings_aws_ecs' or 'settings_prod'."
        )
    try:
        _settings_module = importlib.import_module(
            f".{_h2o_settings_module}", package=__name__
        )
    except ModuleNotFoundError as e:
        # Only intercept "the module itself doesn't exist" -- an ImportError raised from
        # *inside* a module that does exist (e.g. a required env var missing) should
        # propagate as-is rather than being misreported as a bad module name.
        if e.name == f"{__name__}.{_h2o_settings_module}":
            raise ImportError(
                f"H2O_SETTINGS_MODULE={_h2o_settings_module!r} does not name a module "
                f"in {__name__} (looked for {__name__}.{_h2o_settings_module}). "
                "Refusing to fall back to settings_dev -- check for a typo."
            ) from e
        raise
    # Django only reads uppercase settings, so mirror that here instead of doing
    # `import *`, which would also copy the target module's lowercase helper
    # variables (and its own imports, e.g. `os`) into these globals.
    globals().update({k: v for k, v in vars(_settings_module).items() if k.isupper()})
    del _settings_module
else:
    # Try to import the custom settings.py file, which will in turn import one of the deployment targets.
    # If it doesn't exist we assume this is a vanilla development environment and import .settings_dev.
    try:
        from .settings import *  # noqa
    except ImportError as e:
        if e.msg == "No module named 'config.settings.settings'":
            from .settings_dev import *  # noqa
        else:
            raise

del _h2o_settings_module


# Set up Sentry instrumentation
if USE_SENTRY:
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration

    sentry_sdk.init(
        environment=SENTRY_ENVIRONMENT,
        dsn=SENTRY_DSN,
        integrations=[
            DjangoIntegration(),
        ],
        # Set traces_sample_rate to 1.0 to capture 100%
        # of transactions for performance monitoring.
        # We recommend adjusting this value in production.
        traces_sample_rate=SENTRY_TRACES_SAMPLE_RATE,
        # If you wish to associate users to errors (assuming you are using
        # django.contrib.auth) you may enable sending PII data.
        send_default_pii=SENTRY_SEND_DEFAULT_PII,
    )


def validate_settings(settings):
    if bool(settings["AWS_LAMBDA_EXPORT_SETTINGS"].get("function_arn")) == bool(
        settings["AWS_LAMBDA_EXPORT_SETTINGS"].get("function_url")
    ):
        raise AssertionError(
            "Specify either AWS_LAMBDA_EXPORT_SETTINGS['function_arn'] or AWS_LAMBDA_EXPORT_SETTINGS['function_url']"
        )
    if settings["AWS_LAMBDA_EXPORT_SETTINGS"].get("function_arn"):
        parsed = settings["AWS_LAMBDA_EXPORT_SETTINGS"]["function_arn"].split(":")
        assert (
            parsed[0:3] == ["arn", "aws", "lambda"] and parsed[5] == "function"
        ), "AWS_LAMBDA_EXPORT_SETTINGS['function_arn'] must be a valid ARN"
        settings["AWS_LAMBDA_EXPORT_SETTINGS"]["function_region"] = parsed[3]
        settings["AWS_LAMBDA_EXPORT_SETTINGS"]["function_name"] = parsed[6]


validate_settings(globals())
