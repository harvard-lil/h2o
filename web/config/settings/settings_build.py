# Settings for collectstatic during the image build and migration inspection
# by shared CI tooling. Both need the deployed INSTALLED_APPS without secrets.
#
# The deployment targets are unusable at build time: settings_aws_ecs reads
# APP_CONFIG out of the environment on the first line, and that config is a
# runtime secret the builder does not hold. This module imports from
# settings_base exactly as settings_aws_ecs does, so INSTALLED_APPS is the same
# list -- test/test_h2o_settings_module.py asserts that the two agree, since
# the build's output is only correct for production insofar as they do.
#
# Selected per-command in the Dockerfile (H2O_SETTINGS_MODULE=settings_build),
# not baked in: the image's default stays settings_aws_ecs.
from .settings_base import *  # noqa

DEBUG = False

# Django refuses to start with SECRET_KEY unset. Build and inspection commands
# do not sign anything; this public value is only for those commands.
SECRET_KEY = "not-a-secret-this-module-only-runs-at-build-time"
