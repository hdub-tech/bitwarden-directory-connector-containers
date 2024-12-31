#!/bin/bash

#BITWARDENCLI_CONNECTOR_DEBUG=true
SCRIPT_NAME="$( basename "${0}" )"
SUPPORTED_BWDC_SYNCS=( gsuite )
BW_DATAFILE=
BW_ORGUUID=

usage() {
  cat <<EOM
  USAGE:
    ${SCRIPT_NAME} config|test|sync

  Where:
    * config: Finishes necessary configuration using the secrets provided
    * test: Does the above config + runs "bwdc test"
    * sync: Does the above config and test + runs "bwdc sync"

  With the following expectations:
    1. bwdc must be on the path
    2. BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE environment variable must be set
       (should be done in the type specific Dockerfile)
       AND is a supported value (Currently only supports: ${SUPPORTED_BWDC_SYNCS[*]})
    3. BW_CLIENTID and BW_CLIENTSECRET environment variables must be set
    4. If Sync type is gsuite, BW_KEY environment variable must be set
    5. Only one of the above listed arguments should be provided

  Error detected from above list: ${1}
EOM
  exit "${1}"
}

isLoggedOut() {
  # activeUserId does not exist initially and is set to null on logout
  [ ! -e "${BW_DATAFILE}" ] || [[ "$( jq -r '.activeUserId == null' "${BW_DATAFILE}" )" == "true" ]]
}

# login if not already
login() {
  if isLoggedOut; then
    bwdc login
  fi
}

# logout if not already
logout() {
  if ! isLoggedOut; then
    bwdc logout
  fi
}

preReqs() {
  # Make sure we have bwdc
  if which bwdc; then
    BW_DATAFILE="$( bwdc data-file 2>/dev/null )"
  
    # Make sure supported Directory Type set in env var
    if [ -n "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ] \
      && [[ " ${SUPPORTED_BWDC_SYNCS[*]} " =~ [[:space:]]${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}[[:space:]] ]]; then

      # Make sure Client Id and Secret set in env vars for login
      if [ -n "${BW_CLIENTID}" ] && [ -n "${BW_CLIENTSECRET}" ]; then
        BW_ORGUUID="${BW_CLIENTID#organization.}"
      else
        usage 3
      fi
    else
      usage 2
    fi
  else
    usage 1
  fi
}

# Finish secret set-up so not stored in image
config() {
  preReqs

  # bwdc gets angry if you mess with the data.json while logged in
  logout

  # Update organizationId in directoryConfigurations
  BW_DATAFILE_CONTENTS="$( jq -r --arg orgid "${BW_ORGUUID}" '.[$orgid].directorySettings.organizationId = $orgid' "${BW_DATAFILE}" )"
  case "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" in
    "gsuite" | "azure" )
      if [ -z "${BW_KEY}" ]; then
        usage 4
      fi

      # Re-exporting the key variable with newlines sub'ed and then using jq
      # gsub to put them back is the only way I could find to keep jq from
      # double escaping and therefore causing the openssl DECODER error from
      # happening... and I tried a metric ton of things
      export BW_KEY_SUB="${BW_KEY//\\n/::}"
      BW_DATAFILE_CONTENTS="$( echo "${BW_DATAFILE_CONTENTS}" | jq -r --arg orgid "${BW_ORGUUID}" '.[$orgid].directoryConfigurations.gsuite.privateKey = ( $ENV.BW_KEY_SUB | gsub("::"; "\n")? )' )"
  esac

  cp "${BW_DATAFILE}" "${BW_DATAFILE}.old"
  echo "${BW_DATAFILE_CONTENTS}" > "${BW_DATAFILE}"
}

if [ "$#" -ne "1" ]; then
  usage 5
else
  case "${1}" in
    "config" )
      config ;;
    "test" )
      echo TODO test ;;
    "sync" )
      echo TODO sync ;;
    "*" )
      usage 5 ;;
  esac
fi