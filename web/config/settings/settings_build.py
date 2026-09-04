# Settings for the management commands that run during the image build:
# collectstatic and migration_manifest. Both derive their output from
# INSTALLED_APPS, and nothing else here is consulted by either one.
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

# Django refuses to start with SECRET_KEY unset, and neither build command signs
# anything. This value is deliberately not a secret; a container that booted with
# these settings would be serving one it published on GitHub, so nothing selects
# this module except the RUN lines that produce the two build artifacts.
SECRET_KEY = "not-a-secret-this-module-only-runs-at-build-time"
