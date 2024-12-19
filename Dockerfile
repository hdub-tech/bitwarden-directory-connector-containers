FROM debian:12-slim

# Install dependencies
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get -y install --no-install-recommends wget ca-certificates unzip libsecret-1-0 jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set WORKDIR
ENV WORKING_DIR=/bwdc
ARG BWUSER=bitwarden
ARG BWUID=1000
RUN useradd --home-dir $WORKING_DIR --create-home --shell /bin/bash --uid $BWUID $BWUSER
WORKDIR $WORKING_DIR

# Install Bitwarden Directory Connector
ARG BWDC_VERSION=2024.10.0
RUN wget --quiet https://github.com/bitwarden/directory-connector/releases/download/v$BWDC_VERSION/bwdc-linux-$BWDC_VERSION.zip \
    && unzip $WORKING_DIR/bwdc-linux-$BWDC_VERSION.zip -d /usr/local/bin \
    && rm $WORKING_DIR/bwdc-linux-$BWDC_VERSION.zip

RUN --mount=type=secret,id=bw_clientid cp /run/secrets/bw_clientid $WORKING_DIR/.secret && chown $BWUSER:$BWUSER $WORKING_DIR/.secret
USER $BWUSER
ENV BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS=true
RUN bwdc --version && \
    bwdc login && \
    bwdc logout

# TODO Rearrange up when finalized
COPY --chown=$BWUID:$BWUID --chmod=700 entrypoint.sh $WORKING_DIR/

# Do the thing
ENV BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE
ENTRYPOINT ["/bin/bash", "entrypoint.sh", "$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE"]
