FROM docker.io/debian:12-slim

ARG VERSION="dev"
LABEL org.opencontainers.image.authors="hdub-tech@github"
LABEL org.opencontainers.image.source="https://github.com/hdub-tech/bitwarden-directory-connector-images/blob/main/Dockerfile"
LABEL org.opencontainers.image.version=$VERSION

# Install dependencies
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get upgrade \
    && apt-get -y install --no-install-recommends wget ca-certificates unzip libsecret-1-0 jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup non-root user and environment
ENV WORKING_DIR=/bwdc
ARG BWUSER=bitwarden
ARG BWUID=1000
RUN useradd --home-dir $WORKING_DIR --create-home --shell /bin/bash --uid $BWUID $BWUSER
WORKDIR $WORKING_DIR

# Install Bitwarden Directory Connector - needs root for /usr/local/bin
ARG BWDC_VERSION=2024.10.0
RUN wget --quiet https://github.com/bitwarden/directory-connector/releases/download/v$BWDC_VERSION/bwdc-linux-$BWDC_VERSION.zip \
    && unzip $WORKING_DIR/bwdc-linux-$BWDC_VERSION.zip -d /usr/local/bin \
    && rm $WORKING_DIR/bwdc-linux-$BWDC_VERSION.zip

USER $BWUSER
ENV BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS=true
COPY --chown=$BWUID:$BWUID --chmod=700 entrypoint.sh $WORKING_DIR/
ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
