#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
SECRETS_DIR="${SCRIPT_DIR}/.secrets"

BWDC_VERSION=2024.10.0
BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="gsuite"

declare -a BUILD_SECRETS
BUILD_SECRETS+=("--secret=id=bw_clientid,src=${SECRETS_DIR}/bw_clientid")
BUILD_SECRETS+=("--secret=id=bw_clientsecret,src=${SECRETS_DIR}/bw_clientsecret")
declare -a SECRETS
SECRETS+=("--secret=bw_orguuid,type=env,target=BW_ORGUUID")
SECRETS+=("--secret=bw_clientid,type=env,target=BW_CLIENTID")
SECRETS+=("--secret=bw_clientsecret,type=env,target=BW_CLIENTSECRET")
SECRETS+=("--secret=bw_key,type=env,target=BW_KEY")

# Build base
podman build --build-arg BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE" "${BUILD_SECRETS[@]}" -t hdub-tech-bwdc-base:"$BWDC_VERSION" -f Dockerfile

# Build gsuite container
cd gsuite
podman build --build-arg-file=argfile.conf \
  --secret=id=bw_orguuid,src="${SECRETS_DIR}"/bw_orguuid \
  --secret=id=bw_key,src="${SECRETS_DIR}"/bw_key \
  -t hdub-tech-bwdc-gsuite:"$BWDC_VERSION" -f Dockerfile

cat <<EOM
  To run non-interactively:
    podman run ${SECRETS[*]} localhost/hdub-tech-bwdc-$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE:$BWDC_VERSION

  To run interactively:
    podman run ${SECRETS[*]} -it --entrypoint bash localhost/hdub-tech-bwdc-$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE:$BWDC_VERSION
EOM
