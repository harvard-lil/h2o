FROM python:3.5-stretch
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_SRC=/usr/local/src

RUN apt-get update && apt-get install -y nano postgresql-client

# pin node version -- see https://github.com/nodesource/distributions/issues/33
RUN curl -o nodejs.deb https://deb.nodesource.com/node_12.x/pool/main/n/nodejs/nodejs_12.13.1-1nodesource1_amd64.deb \
    && dpkg -i ./nodejs.deb \
    && rm nodejs.deb

# Install Pandoc, for export
RUN wget https://github.com/jgm/pandoc/releases/download/2.8.1/pandoc-2.8.1-1-amd64.deb \
    && dpkg -i pandoc-2.8.1-1-amd64.deb

RUN mkdir -p /app/_python
WORKDIR /app/_python

# pip
COPY _python/requirements.txt /app/_python
RUN pip install pip==19.3.1 \
    && pip install -r requirements.txt \
    && rm requirements.txt
