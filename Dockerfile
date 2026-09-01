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

# The suite writes into the project dir: collectstatic to STATIC_ROOT
# (BASE_DIR/static), pytest's coverage.xml, and npm's node_modules/.npmcache
# and static/dist. prod already COPYs web/ as h2o, so these are writable.
USER h2o
