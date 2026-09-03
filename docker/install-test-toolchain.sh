#!/usr/bin/env bash
#
# Node + Playwright + the X11 libraries its browsers need.
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
    gnupg \
    nano \
    postgresql-client

# pin node version -- see https://github.com/nodesource/distributions/issues/33#issuecomment-1698870039 and
# https://github.com/nodesource/distributions/wiki/How-to-select-the-Node.js-version-to-install
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" \
    | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-cache policy nodejs
apt-get install --yes nodejs=16.14.0-1nodesource1

# Shared libraries Playwright's chromium/firefox builds link against
apt-get install -y --no-install-recommends \
    libdbus-glib-1-2 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libatspi2.0-0 \
    libwayland-client0 \
    libx11-xcb1 \
    libxcursor1 \
    libgtk-3-0

playwright install chromium firefox

# Readable by whatever user the stage ends up running as.
chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"

rm -rf /var/lib/apt/lists/*
