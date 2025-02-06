# USAGE:
#  BUILD:
#    Defaults:
#    podman build --build-arg-file defaults.conf -t hdub-tech/bwdc-base:BWDC_VERSION -f Containerfile
#
#    Overridesa:
#    podman build --build-arg-file custom.conf -t hdub-tech/bwdc-base:dev -f Containerfile
#
#  RUN:
#    Non-interactive:
#    podman run --env-file $BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/env.vars --rm --volume /PATH/TO/DATA_JSON_DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id hdub-tech/bwdc-base:BWDC_VERSION [-h] [-c] [-t] [-s]
#
#    Interactive:
#    podman run --env-file $BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE/env.vars -it --entrypoint bash --rm --volume /PATH/TO/DATA_JSON_DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id hdub-tech/bwdc-base:BWDC_VERSION
#    bitwarden@deadbeef1234:~$ ./entrypoint -h  #List help for container script
#    bitwarden@deadbeef1234:~$ bwdc help        #Use raw bwdc cli with your mounted data.json
#
FROM docker.io/debian:12-slim

LABEL org.opencontainers.image.title="bwdc-base"
LABEL org.opencontainers.image.authors="hdub-tech@github"
LABEL org.opencontainers.image.source="https://github.com/hdub-tech/bitwarden-directory-connector-containers/blob/main/Containerfile"
LABEL org.opencontainers.image.licenses="GPL-3.0"

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
ARG BWDC_VERSION
RUN wget --quiet https://github.com/bitwarden/directory-connector/releases/download/v$BWDC_VERSION/bwdc-linux-$BWDC_VERSION.zip \
    && unzip $WORKING_DIR/bwdc-linux-$BWDC_VERSION.zip -d /usr/local/bin \
    && rm $WORKING_DIR/bwdc-linux-$BWDC_VERSION.zip
LABEL org.opencontainers.image.version=$BWDC_VERSION
LABEL org.opencontainers.image.description="Contains bwdc (Version: ${BWDC_VERSION}), ${BWUSER} user (id=${BWUID}, home=${WORKING_DIR}) and an entrypoint.sh script for config, test and sync"

USER $BWUSER
RUN mkdir --parents $WORKING_DIR/.config/Bitwarden\ Directory\ Connector
ENV BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS=true
COPY --chown=$BWUID:$BWUID --chmod=700 entrypoint.sh $WORKING_DIR/
ENTRYPOINT ["/bin/bash", "entrypoint.sh"]
