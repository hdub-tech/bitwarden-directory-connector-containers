#!/bin/bash

# Constants
#BITWARDENCLI_CONNECTOR_DEBUG=true
SCRIPT_NAME="$( basename "${0}" )"
SUPPORTED_BWDC_SYNCS=( gsuite )
BW_DATAFILE=
BW_ORGUUID=
ERROR_FILE=/tmp/entrypoint.log

# Configurable args
CONFIG=
TEST=
SYNC=
# TODO -z: Zero out secrets in config file when done/error (Specifically
# useful for people using mounted data.json which did not contain secrets
# before running this script)

usage() {
  cat <<EOM
  USAGE:
    ${SCRIPT_NAME} [-c] [-t] [-s] [-h]

  Where at least one of the following is required:
    * -c: (aka config) - Configures data.json with env var secrets (Use this
                         option when using the config file method, or the BYO
                         data.json method and the data.json does not contain
                         secrets. Omit this option if using your own data.json
                         and it already has the secrets populated).
    * -t: (aka test)   - Runs "bwdc test", with bwdc login if necessary, and
                         bwdc logout when completed (even if error).
    * -s: (aka sync)   - Runs "bwdc sync", with bwdc login if necessary, and
                         bwdc logout when completed (even if error). THIS DOES
                         NOT RUN A TEST FIRST!
    * -h: (aka help)   - Display this usage message

  With the following expectations:
    1. bwdc must be on the path
    2. BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE environment variable must be set
       (should be done in the type specific Containerfile) to use config option
       AND must be a supported value (Currently only supports:
       ${SUPPORTED_BWDC_SYNCS[*]})
    3. BW_CLIENTID and BW_CLIENTSECRET environment variables must be set
    4. If Sync type is gsuite, BW_GSUITEKEY environment variable must be set
    5. At least one of the above listed arguments should be provided

  Examples (NOTE: this script always executes in config>test>sync order
  regardless of the order of the options supplied to it. It WILL exit early if a
  step fails):

    Configure the data.json file with the secrets, run bwdc test, and run bwdc sync
      ${0} -c -t -s

    Configure the data.json file with the secrets and run bwdc test
      ${0} -c -t

    Run a test and run a sync, but do NOT configure data.json
      ${0} -t -s
EOM
  [ "0" -ne "${1}" ] && echo "Error detected from above list: ${1}"
  exit "${1}"
}

isLoggedOut() {
  # activeUserId does not exist initially and is set to null on logout
  [ ! -e "${BW_DATAFILE}" ] || [[ "$( jq -r '.activeUserId == null' "${BW_DATAFILE}" )" == "true" ]]
}

# login if not already
login() {
  if isLoggedOut; then
    bwdc login || exit 7
  fi
}

# logout if not already
logout() {
  if ! isLoggedOut; then
    bwdc logout || exit 8
  fi
}

preReqs() {
  # Make sure we have bwdc for all modes
  if which bwdc &>/dev/null; then
    BW_DATAFILE="$( bwdc data-file 2>/dev/null )"
  
    # Make sure Client Id and Secret set in env vars for login
    if [ -n "${BW_CLIENTID}" ] && [ -n "${BW_CLIENTSECRET}" ]; then
      BW_ORGUUID="${BW_CLIENTID#organization.}"

      # Make sure supported Directory Type set in env var for config
      if [ -n "${CONFIG}" ] \
        && [ -n "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ] \
        && [[ ! " ${SUPPORTED_BWDC_SYNCS[*]} " =~ [[:space:]]${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}[[:space:]] ]]; then

        usage 2
      fi
    else
      usage 3
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

  # Do type specific substitutions
  case "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" in
    "gsuite" )
      if [ -z "${BW_GSUITEKEY}" ]; then
        usage 4
      fi

      # Re-exporting the key variable with newlines sub'ed and then using jq
      # gsub to put them back is the only way I could find to keep jq from
      # double escaping and therefore causing the openssl DECODER error from
      # happening... and I tried a metric ton of things
      export BW_KEY_SUB="${BW_GSUITEKEY//\\n/::}"
      BW_DATAFILE_CONTENTS="$( echo "${BW_DATAFILE_CONTENTS}" | jq -r --arg orgid "${BW_ORGUUID}" '.[$orgid].directoryConfigurations.gsuite.privateKey = ( $ENV.BW_KEY_SUB | gsub("::"; "\n")? )' )"
      ;;
  esac

  # Backup original data.json before overwriting it
  cp "${BW_DATAFILE}" "${BW_DATAFILE}.old"
  echo "${BW_DATAFILE_CONTENTS}" > "${BW_DATAFILE}"

  # Running bwdc data-file will detect malformed JSON, and acts as a success
  # metric. However, it will repair the file and simply return success, hence
  # the redirect stderr to file and make sure file size is zero hack
  echo -n "Data file updated: "
  bwdc data-file 2>"${ERROR_FILE}"
  if [ -s "${ERROR_FILE}" ]; then
    echo "Failure validating configuration file:"
    cat "${ERROR_FILE}"
    exit 6
  else
    echo "Configuration completed successfully"
  fi
}

bwdcTest() {
  login
  bwdc test --pretty || test_failed=true
  # Always logout
  logout

  if [ -n "${test_failed}" ]; then
    exit 9
  else
    echo "'bwdc test' completed successfully"
  fi
}

bwdcSync() {
  login
  bwdc sync || test_failed=true
  # Always logout
  logout

  if [ -n "${test_failed}" ]; then
    exit 10
  else
    echo "'bwdc sync' completed successfully"
  fi
}

while getopts "ctsh" opt; do
  case "${opt}" in
    "c" )
      CONFIG=true ;;
    "t" )
      TEST=true ;;
    "s" )
      SYNC=true ;;
    "h" )
      usage 0 ;;
    * )
      usage 5 ;;
  esac
done

if [ -z "${CONFIG}" ] && [ -z "${TEST}" ] && [ -z "${SYNC}" ]; then
  usage 5
else
  preReqs
  [ -n "${CONFIG}" ] && config
  [ -n "${TEST}" ] && bwdcTest
  [ -n "${SYNC}" ] && bwdcSync
  exit 0
fi
