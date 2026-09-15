#!/usr/bin/env bash
#
# PostgreSQL client, Playwright, and the system libraries its browsers need.
#
# Shared by the `dev` and `test` targets in ../Dockerfile so the two stay in
# lockstep: `dev` is what a developer runs against a bind-mounted checkout,
# `test` is the same toolchain layered onto the real prod artifact in CI. If
# these drifted apart, CI and local development would stop agreeing about what
# the test suite runs on -- which is the whole problem this file exists to avoid.
#
# Installs browsers into $PLAYWRIGHT_BROWSERS_PATH (set by both targets) and
# makes them world-readable, so a stage that drops to a non-root user after
# running this can still launch them.
set -euxo pipefail

: "${PLAYWRIGHT_BROWSERS_PATH:?must be set by the calling Dockerfile stage}"

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    nano \
    curl

# Match the database service's major version, including pg_dump/pg_restore.
install -d /usr/share/postgresql-common/pgdg
curl --fail --silent --show-error --location \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
cat > /etc/apt/sources.list.d/pgdg.sources <<'EOF'
Types: deb
URIs: https://apt.postgresql.org/pub/repos/apt
Suites: trixie-pgdg
Components: main
Signed-By: /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
EOF
apt-get update
apt-get install -y --no-install-recommends postgresql-client-16

playwright install --with-deps chromium firefox

# Readable by whatever user the stage ends up running as.
chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"

rm -rf /var/lib/apt/lists/*
