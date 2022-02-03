FROM registry.lil.tools/library/python:3.9-bullseye
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
    libcurl4-openssl-dev

# (Add Lambda Runtime Interface Emulator and set up the entrypoint script
ARG lambda-rie-cache-buster
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/local/bin/aws-lambda-rie
COPY entrypoint.sh /
RUN chmod 755 /usr/local/bin/aws-lambda-rie /entrypoint.sh
EXPOSE 8080

ARG BUILDARCH
ENV BUILDARCH=${BUILDARCH:-amd64}

# Install Pandoc
RUN wget https://github.com/jgm/pandoc/releases/download/2.14.2/pandoc-2.14.2-1-${BUILDARCH}.deb \
    && dpkg -i pandoc-2.14.2-1-${BUILDARCH}.deb

# Install the python requirements, including the AWS Lambda runtime interface client
COPY function/requirements.txt .
RUN pip install pip==21.3.1 \
    && pip install -r requirements.txt \
    && rm requirements.txt

# Add the function code
RUN mkdir -p /function
WORKDIR /function
COPY function/* ./

# Set CMD to the handling function defined in app.py, and via the entrypoint, arrange for
# that function to be run via actual AWS Lambda or via the container's own Lambda runtime emulator,
# whichever is correct for the environment.
CMD [ "app.handler" ]
ENTRYPOINT [ "/entrypoint.sh" ]
