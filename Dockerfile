# =====================================================================
# base -- shared Python/uv layer. No app code. Not run directly.
# =====================================================================
FROM ghcr.io/astral-sh/uv:0.12.13 AS uv
FROM node:24.21.0-trixie AS node

FROM python:3.14-trixie AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY --from=uv /uv /uvx /usr/local/bin/
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_PYTHON_DOWNLOADS=never \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app/web

# Copy only the dependency manifest and lockfile first so this expensive layer is cached
# and shared by every target below, independent of app-code changes.
COPY web/pyproject.toml web/uv.lock ./

# CPUCOUNT=1 makes uwsgi compile single-threaded. Its build spawns one thread
# per CPU, each shelling out to gcc, and on a loaded runner one of those forks
# intermittently dies with "OSError: [Errno 14] Bad address: '/bin/sh'", failing
# the whole image build. Serialising it trades a little time for a build that
# does not fail at random.
RUN CPUCOUNT=1 uv sync --locked --no-dev --no-cache

# =====================================================================
# assets -- the compiled JS/CSS bundles. Built here rather than by running
# the test image and committing the result, so that `prod` and `test` come
# out of one build graph and cannot disagree about what the frontend is.
#
# Uses the plain node image rather than `base`: this stage needs npm and
# nothing Python, and pinning here keeps it off the Playwright toolchain.
# =====================================================================
FROM node AS assets

WORKDIR /app/web

# Dependencies first, so a frontend edit does not reinstall node_modules.
COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/vite.config.mjs ./
# static/ is an input as well as the output location: the SCSS resolves
# `static/images/*.svg` at build time. static/dist comes along too and is
# simply overwritten by the build below.
COPY web/static ./static
COPY web/frontend ./frontend

# The tested artifact keeps the same release identifier through both deploy tiers.
ARG H2O_RELEASE=

# Vite emits a manifest and production bundles with /static/dist paths.
RUN npm run build

# =====================================================================
# prod -- the deployable artifact. uwsgi, non-root user, app code baked in.
# =====================================================================
FROM base AS prod

ARG H2O_RELEASE=
ENV H2O_RELEASE=$H2O_RELEASE

# uWSGI is installed at its locked version in base.

# Create a non-root user and set up permissions
RUN useradd -m -r h2o && chown -R h2o /app

# Copy the application code
COPY --chown=h2o:h2o web/ .

# Overwrite whatever bundles the checkout happened to carry with the ones just
# built. This is what makes the shipped image self-contained: it no longer
# depends on anyone having committed a current build.
COPY --from=assets --chown=h2o:h2o /app/web/static/dist ./static/dist

# Select deployment settings at runtime via config/settings/__init__.py
# (H2O_SETTINGS_MODULE), instead of baking a settings.py into the image.
ENV H2O_SETTINGS_MODULE=settings_aws_ecs

USER h2o

# Collect package static files into the image so they can be extracted
# without running the application.
#
# collectstatic fills STATIC_ROOT -- /app/web/static, the directory this stage
# has been assembling -- with the files that come from installed packages:
# admin, rest_framework, django_extensions, css. Those sit beside the committed
# static files and the bundles copied above, so WhiteNoise can answer for every
# static URL the app renders.
#
# Build-only settings avoid requiring deployed APP_CONFIG. Migration inspection
# is performed by shared tooling against this image during CI publication.
RUN H2O_SETTINGS_MODULE=settings_build ./manage.py collectstatic --noinput

EXPOSE 8000

# --die-on-term is what makes SIGTERM mean "shut down". uwsgi's own meaning for
# it is "brutally reload", so without this the master ignores the signal ECS
# sends to stop a task, ECS waits out the stop timeout and kills it, and
# whatever the workers were serving dies with them. That defeats the drain the
# cloudflared sidecar performs ahead of it: the connector stops taking new
# requests and finishes its in-flight ones, and then uwsgi is shot anyway.
CMD ["uwsgi", "--http", "0.0.0.0:8000", "--master", "--die-on-term", "--processes", "20", "--threads", "1", "--buffer-size", "32768", "--module", "config.wsgi"]

# =====================================================================
# dev -- local development. The test toolchain on top of `base`, with no app
# code: docker-compose bind-mounts the working tree at /app so a developer
# edits and reruns without rebuilding.
# =====================================================================
FROM base AS dev

RUN uv sync --locked --group dev --no-cache

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

COPY docker/install-test-toolchain.sh /tmp/install-test-toolchain.sh
RUN /tmp/install-test-toolchain.sh && rm /tmp/install-test-toolchain.sh

# =====================================================================
# test -- what CI runs the suite against. FROM prod, so it carries prod's
# uwsgi layer, prod's non-root user and prod's baked-in code, plus the same
# toolchain `dev` gets. Tests therefore exercise the artifact that ships
# rather than a sibling of it.
#
# The toolchain must be installed as root, but the stage ends as `h2o` again
# so the suite runs under prod's real permissions -- if the app can't write
# somewhere in production, CI finds out here.
# =====================================================================
FROM prod AS test

USER root

RUN uv sync --locked --group dev --no-cache

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

COPY docker/install-test-toolchain.sh /tmp/install-test-toolchain.sh
RUN /tmp/install-test-toolchain.sh && rm /tmp/install-test-toolchain.sh

# npm lint and the JS unit tests need node_modules, which prod has no business
# carrying. Taken from the assets stage rather than reinstalled, so the tests run
# against the very tree the bundles were built from.
COPY --from=assets --chown=h2o:h2o /app/web/node_modules ./node_modules

# The bundles are already baked in by the prod stage, and there are no npm
# sources here to rebuild them from, so the freshness check must not fire.
ENV H2O_SKIP_ASSET_CHECK=1

# The suite writes pytest's coverage.xml into the project dir. prod COPYs web/
# as h2o and runs its build commands as h2o, so the project dir and STATIC_ROOT
# are both writable here.
USER h2o
