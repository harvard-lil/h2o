# =====================================================================
# base -- shared Python/pip layer. No app code. Not run directly.
# =====================================================================
FROM python:3.11-bookworm AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

WORKDIR /app/web

# Copy only the requirements file first so this expensive layer is cached
# and shared by every target below, independent of app-code changes.
COPY web/requirements.txt .

RUN pip install pip==24.0 \
    && pip install --no-cache-dir -r requirements.txt

# =====================================================================
# assets -- the compiled JS/CSS bundles. Built here rather than by running
# the test image and committing the result, so that `prod` and `test` come
# out of one build graph and cannot disagree about what the frontend is.
#
# Uses the plain node image rather than `base`: this stage needs npm and
# nothing Python, and pinning here keeps it off the Playwright toolchain.
# Node version tracks docker/install-test-toolchain.sh.
# =====================================================================
FROM node:16.14.0-bullseye AS assets

WORKDIR /app/web

# Dependencies first, so a frontend edit does not reinstall node_modules.
COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/babel.config.js web/vue.config.js ./
# static/ is an input as well as the output location: the SCSS resolves
# `static/images/*.svg` at build time. static/dist comes along too and is
# simply overwritten by the build below.
COPY web/static ./static
COPY web/frontend ./frontend

# vue-cli-service build sets NODE_ENV=production, which makes vue.config.js
# emit webpack-stats.json (not the -serve variant) with /static/dist paths.
RUN npm run build

# =====================================================================
# prod -- the deployable artifact. uwsgi, non-root user, app code baked in.
# =====================================================================
FROM base AS prod

# Install the uwsgi build toolchain, build uwsgi, then drop the toolchain
# so it doesn't ship in the runtime image -- uwsgi itself only needs libpcre3.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpcre3 \
        libpcre3-dev \
    && pip install --no-cache-dir uwsgi \
    && apt-get purge -y --auto-remove build-essential libpcre3-dev \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user and set up permissions
RUN useradd -m -r h2o && chown -R h2o /app

# Copy the application code
COPY --chown=h2o:h2o web/ .

# Overwrite whatever bundles the checkout happened to carry with the ones just
# built. This is what makes the shipped image self-contained: it no longer
# depends on anyone having committed a current build.
COPY --from=assets --chown=h2o:h2o /app/web/static/dist ./static/dist
COPY --from=assets --chown=h2o:h2o /app/web/webpack-stats.json ./webpack-stats.json

# Select deployment settings at runtime via config/settings/__init__.py
# (H2O_SETTINGS_MODULE), instead of baking a settings.py into the image.
ENV H2O_SETTINGS_MODULE=settings_aws_ecs

USER h2o

EXPOSE 8000

CMD ["uwsgi", "--http", "0.0.0.0:8000", "--master", "--processes", "20", "--threads", "1", "--buffer-size", "32768", "--module", "config.wsgi"]

# =====================================================================
# dev -- local development. The test toolchain on top of `base`, with no app
# code: docker-compose bind-mounts the working tree at /app so a developer
# edits and reruns without rebuilding.
# =====================================================================
FROM base AS dev

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

# The suite writes into the project dir: collectstatic to STATIC_ROOT
# (BASE_DIR/static) and pytest's coverage.xml. prod already COPYs web/ as h2o,
# so these are writable.
USER h2o
