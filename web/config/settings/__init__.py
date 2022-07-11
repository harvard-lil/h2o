# This is the base module that will be imported by Django.

# Try to import the custom settings.py file, which will in turn import one of the deployment targets.
# If it doesn't exist we assume this is a vanilla development environment and import .deployments.settings_dev.
try:
    from .settings import *  # noqa
except ImportError as e:
    if e.msg == "No module named 'config.settings.settings'":
        from .settings_dev import *  # noqa
    else:
        raise


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
