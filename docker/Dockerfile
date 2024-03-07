FROM registry.lil.tools/library/python:3.11-bookworm
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_SRC=/usr/local/src

RUN apt-get update && apt-get install -y nano postgresql-client

# pin node version -- see https://github.com/nodesource/distributions/issues/33#issuecomment-1698870039 and
# https://github.com/nodesource/distributions/wiki/How-to-select-the-Node.js-version-to-install
RUN apt install -y ca-certificates gnupg \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt update \
    && apt-cache policy nodejs \
    && apt install --yes nodejs=16.14.0-1nodesource1

RUN mkdir -p /app/web
WORKDIR /app/web

# pip
COPY web/requirements.txt /app/web
RUN pip install pip==21.3.1 \
    && pip install -r requirements.txt \
    && rm requirements.txt

# Install Playwright browsers for integration tests
RUN  apt-get update && apt install -y --no-install-recommends libdbus-glib-1-2 \
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
    libwayland-client0

RUN playwright install chromium firefox