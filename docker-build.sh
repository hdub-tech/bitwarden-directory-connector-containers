#!/bin/bash

set -e

BWDC_VERSION=2024.10.0
podman build -t hdub-tech-bwdc:"$BWDC_VERSION" -f Dockerfile
podman build -t hdub-tech-bwdc-gsuite:"$BWDC_VERSION" -f gsuite.Dockerfile

SECRETS="--secret=bw_key,type=mount,uid=1000,mode=0400 --secret=bw_clientid,type=env,target=BW_CLIENTID --secret=bw_clientsecret,type=env,target=BW_CLIENTSECRET"
echo
echo "To run default:"
echo podman run "$SECRETS" localhost/hdub-tech-bwdc-gsuite:"$BWDC_VERSION"

echo "To run interactively:"
echo podman run "$SECRETS" -it --entrypoint bash localhost/hdub-tech-bwdc-gsuite:"$BWDC_VERSION"
