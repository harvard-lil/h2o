FROM ruby:2.4.1-stretch

RUN mkdir /h2o
WORKDIR /h2o

RUN apt-get update \
    && apt-get install -y build-essential \
    && apt-get install -y libpq-dev \
    # solr_sunspot needs Java
    && apt-get install -y ca-certificates-java \
    && apt-get install -y openjdk-8-jre \
    && apt-get install -y openjdk-8-jre-headless \
    && apt-get install -y openjdk-8-jdk \
    && apt-get install -y openjdk-8-jdk-headless \
    # Chrome for test:system, technique from https://github.com/SeleniumHQ/docker-selenium/blob/master/NodeChrome/Dockerfile.txt
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get -y install google-chrome-stable \
    && CHROME_MAJOR_VERSION=$(google-chrome --version | sed -E "s/.* ([0-9]+)(\.[0-9]+){3}.*/\1/") \
    && CHROME_DRIVER_VERSION=$(wget --no-verbose -O - "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${CHROME_MAJOR_VERSION}") \
    && wget https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip \
    && apt-get -y install unzip \
    && unzip chromedriver_linux64.zip \
    && mv chromedriver /usr/bin/chromedriver \
    && chmod +x /usr/bin/chromedriver \
    && rm -rf /var/lib/apt/lists/*

# Get Node 10 instead of version in APT repository.
# Downloads an installation script, which ends by running
# apt-get update: no need to re-run at this layer.
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get install -y nodejs

# Get yarn.
# Removes cmdtest due to conflicting command name
# https://github.com/yarnpkg/yarn/issues/2821
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get remove cmdtest \
    && apt-get install --no-install-recommends -y yarn

# Ruby dependencies
COPY Gemfile /h2o/Gemfile
COPY Gemfile.lock /h2o/Gemfile.lock
# Pin bundler for now: guard-bundler wants version ~>1.0
RUN gem install bundler -v '1.17.3' && bundle install

# Node dependencies
COPY package.json /h2o/package.json
COPY yarn.lock /h2o/yarn.lock
RUN yarn install --frozen-lockfile

# Less important packages; can move up in this file if desired
RUN apt-get update \
    && apt-get install -y nano \
    && apt-get install -y wdiff

# Custom version of Pandoc, for export
RUN wget https://lilresources.s3.amazonaws.com/h2o/pandoc-889810d -O /usr/bin/pandoc \
    && chmod +x /usr/bin/pandoc

