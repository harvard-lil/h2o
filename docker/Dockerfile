FROM registry.lil.tools/library/python:3.9-bullseye
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_SRC=/usr/local/src

RUN apt-get update && apt-get install -y nano postgresql-client

# pin node version -- see https://github.com/nodesource/distributions/issues/33
RUN curl -o nodejs.deb https://deb.nodesource.com/node_16.x/pool/main/n/nodejs/nodejs_16.14.0-deb-1nodesource1_$(dpkg --print-architecture).deb \
    && dpkg -i ./nodejs.deb \
    && rm nodejs.deb

RUN mkdir -p /app/web
WORKDIR /app/web

# pip
COPY web/requirements.txt /app/web
RUN pip install pip==21.3.1 \
    && pip install -r requirements.txt \
    && rm requirements.txt

# Install Playwright browsers for integration tests
RUN apt-get update && apt install -y --no-install-recommends libdbus-glib-1-2
RUN playwright install chromium firefox