FROM ghcr.io/astral-sh/uv:0.12.13 AS uv
FROM python:3.14-trixie
COPY --from=uv /uv /uvx /usr/local/bin/
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_PYTHON_DOWNLOADS=never \
    PATH="/opt/venv/bin:$PATH"
ARG TARGETARCH
ARG PANDOC_VERSION=3.11
ARG LAMBDA_RIE_VERSION=1.37
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_SRC=/usr/local/src

# Install aws-lambda-cpp build dependencies
RUN apt-get update && \
    apt-get install -y \
    g++ \
    make \
    cmake \
    unzip \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Add Lambda Runtime Interface Emulator and set up the entrypoint script
RUN case "$TARGETARCH" in \
        amd64) rie_arch=x86_64 ;; \
        arm64) rie_arch=arm64 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/v${LAMBDA_RIE_VERSION}/aws-lambda-rie-${rie_arch}" -o /usr/local/bin/aws-lambda-rie
COPY entrypoint.sh /
RUN chmod 755 /usr/local/bin/aws-lambda-rie /entrypoint.sh
EXPOSE 8080

# Install Pandoc
RUN curl -fsSL "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-${TARGETARCH}.deb" -o /tmp/pandoc.deb \
    && dpkg -i /tmp/pandoc.deb \
    && rm /tmp/pandoc.deb

# Install the python requirements, including the AWS Lambda runtime interface client
WORKDIR /opt/lambda
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-cache

# Add the function code
RUN mkdir -p /function
WORKDIR /function
COPY function /function

# Set CMD to the handling function defined in app.py, and via the entrypoint, arrange for
# that function to be run via actual AWS Lambda or via the container's own Lambda runtime emulator,
# whichever is correct for the environment.
CMD [ "app.handler" ]
ENTRYPOINT [ "/entrypoint.sh" ]
