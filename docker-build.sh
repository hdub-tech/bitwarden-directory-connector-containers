#!/bin/bash

set -e

BWDC_VERSION=2024.10.0
BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="gsuite"

declare -a BUILD_SECRETS
BUILD_SECRETS+=("--secret=id=bw_clientid,src=areyoukiddingme/.bw_clientid")
declare -a SECRETS
SECRETS+=("--secret=bw_orguuid,type=env,target=BW_ORGUUID")
SECRETS+=("--secret=bw_clientid,type=env,target=BW_CLIENTID")
SECRETS+=("--secret=bw_clientsecret,type=env,target=BW_CLIENTSECRET")
SECRETS+=("--secret=bw_key,type=env,target=BW_KEY")

podman build --no-cache --env BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE" "${BUILD_SECRETS[*]}" -t hdub-tech-bwdc-"$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE":"$BWDC_VERSION" -f Dockerfile

cat <<EOM
  To run non-interactively:
    podman run ${SECRETS[*]}" localhost/hdub-tech-bwdc-$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE:$BWDC_VERSION

  To run interactively:
    podman run ${SECRETS[*]} -it --entrypoint bash localhost/hdub-tech-bwdc-$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE:$BWDC_VERSION
EOM
