#!/bin/bash
# DEPENDENCIES: jq and base64

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
SCRIPT_NAME="$( basename "$0" )"
SECRETS_DIR="${SCRIPT_DIR}/.secrets"
USER=$( id --user )

usage() {
  cat <<EOM
  USAGE:
    $SCRIPT_NAME setup secretid1 [secretid2 ... secretidN]
    $SCRIPT_NAME teardown

   - "setup" will pull the secrets out of the podman secrets manager and write them
     to disk because podman build has pointless secrets management
   - "teardown" will delete the plain text secrets on disk

   This is a temporary solution until this is in a place with proper secrets
   management
EOM
}

setup() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi

  if [ ! -d "${SECRETS_DIR}" ]; then
    #TODO: Debated throwing error if it exists
    mkdir "${SECRETS_DIR}"
    chmod 0700 "${SECRETS_DIR}"
  fi

  for psecret in "$@" ; do
    if podman secret exists "$psecret"; then
      declare -a FILE_AND_ID
      mapfile -t FILE_AND_ID < <( podman secret inspect "$psecret" | jq -r '.[0].Spec.Driver.Options.path, .[0].ID' )
      ENCODED=$( jq -r --arg secretid "${FILE_AND_ID[1]}" '.[$secretid]' "${FILE_AND_ID[0]}"/secretsdata.json )
      SECRET_FILE="${SECRETS_DIR}/$psecret"
      echo "${ENCODED}" | base64 -d > "${SECRET_FILE}"
      chmod 0400 "${SECRET_FILE}"
    else
      echo "$psecret doesn't exist in local storage"
      exit 1
    fi
  done
}

teardown() {
  [ -d "$SECRETS_DIR" ] && rm -r "$SECRETS_DIR"
}

if [ -z "$1" ]; then
  usage
  exit 1
fi

case "$1" in
  "setup" )
    shift
    setup "$@"
    ;;
  "teardown" ) teardown ;;
  * )
    usage
    exit 1
    ;;
esac
