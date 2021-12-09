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
    if settings['AWS_LAMBDA_EXPORT_FUNCTION_ARN']:
        parsed = settings['AWS_LAMBDA_EXPORT_FUNCTION_ARN'].split(':')
        assert parsed[0:3] == ['arn', 'aws', 'lambda'] and parsed[5] == 'function', 'AWS_LAMBDA_EXPORT_FUNCTION_ARN must be a valid ARN'
        settings['AWS_LAMBDA_EXPORT_FUNCTION_REGION'] = parsed[3]
        settings['AWS_LAMBDA_EXPORT_FUNCTION_NAME'] = parsed[6]

validate_settings(globals())
