#!/bin/bash

# TODO convert to compose file?

# Constants
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}"/functions.sh
SUPPORTED_BWDC_SYNCS=( gsuite )
SUPPORTED_SECRETS_MANAGERS=( podman env )

# Configurable in custom.conf file
# The following will be set to BDCC_VERSION if USE_BDCC_VERSION_FOR_TYPED=true
BWDC_VERSION=
SECRETS_MANAGER=
IMAGE_NAMESPACE=
USE_BDCC_VERSION_FOR_TYPED=false
# Source conf file with defaults
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/defaults.conf"

# Configurable script args
BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE=
NO_CACHE=
OPTIONAL_REBUILD_BWDC_LOGIN_STAGE=
# If a custom conf, source it for overrides
# shellcheck disable=SC1091
[ -e "${SCRIPT_DIR}/custom.conf" ] && . "${SCRIPT_DIR}/custom.conf"

USAGE_HELP=0
USAGE_ERROR=255
usage() {
  cat <<EOM
  USAGE:
    ${SCRIPT_NAME} -t BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE [-n] [-r] [-u]

   - BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE is one of: [${SUPPORTED_BWDC_SYNCS[*]}]
   - Use "-n" to build all container images without cache (podman --no-cache)
   - Use "-r" to rebuild the final run stage of the type specific container (allows you to test login)
   - Use "-u" to view the How-to run bwdc-\$TYPE-\$CONFNAME usage

EOM

  # If usage was called without args, exit as error
  RC="${1:-USAGE_ERROR}"
  exit "${RC}"
}

# 1: functionName, 2: numArgsActual, 3: numArgsExpected
functionArgCheck() {
  if [ "${2}" -lt "${3}" ]; then
    message "${SCRIPT_NAME}" "ERROR" "${1} requires at least ${3} args"
    exit 4
  fi
}

# uppercase all arguments
uppercase() {
  functionArgCheck "${0}" $# 1

  echo "$@" | tr '[:lower:]' '[:upper:]'
}

# extract the specified podman secrets to a corresponding environment var
exportPodmanSecrets() {
  functionArgCheck "${0}" $# 1

  for psecret in "$@" ; do
    if podman secret exists "${psecret}"; then
      declare -a FILE_AND_ID
      # Select the file with the specified secret as well as its Hex ID
      mapfile -t FILE_AND_ID < <( podman secret inspect "${psecret}" | jq -r '.[0].Spec.Driver.Options.path, .[0].ID' )
      # Extract the encoded secret from file using its Hex ID and b64 decode
      SECRET_VALUE=$( jq -r --arg secretid "${FILE_AND_ID[1]}" '.[$secretid] | @base64d' "${FILE_AND_ID[0]}"/secretsdata.json )
      SECRET_KEY="$( uppercase "${psecret}" )"
      export "${SECRET_KEY}"="${SECRET_VALUE}"
    else
      message "${SCRIPT_NAME}" "ERROR" "${psecret} doesn't exist in podman local storage"
      exit 5
    fi
  done
}

# env secrets SHOULD already be exported in this env and this confirms it
confirmEnvSecrets() {
  functionArgCheck "${0}" $# 1

  for env in "$@"; do
    if [ -z "${!env}" ]; then  # The ! allows Indirect Ref to env var
      message "${SCRIPT_NAME}" "ERROR" "SECRETS_MANAGER=env but ${env} not exported in this environment"
      exit 6
    fi
  done
}

# Generic export secrets function with error handling, calls exports by type
exportSecrets() {
  functionArgCheck "${0}" $# 1

  case "${SECRETS_MANAGER}" in
    "podman" ) exportPodmanSecrets "$@" ;;
    "env" )
      # shellcheck disable=SC2048,SC2086
      confirmEnvSecrets ${*@U} ;;
  esac
}

# Build gsuite sync image(s)
buildGsuite() {
  exportSecrets bw_clientid bw_clientsecret

  cd "${SCRIPT_DIR}"/"${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" || exit 1

  # Exit if no conf files
  ! ls ./*.conf && exit 7

  for conf in *.conf; do
    # shellcheck disable=SC1090
    . "${conf}"
    conf_name="$( basename "${conf%.conf}" )"
    # shellcheck disable=SC2086
    podman build ${NO_CACHE} \
      ${OPTIONAL_REBUILD_BWDC_LOGIN_STAGE} \
      --build-arg-file="${conf}" \
      --secret=id=bw_clientid,env=BW_CLIENTID \
      --secret=id=bw_clientsecret,env=BW_CLIENTSECRET \
      --build-arg BWDC_VERSION="${BWDC_VERSION}" \
      --build-arg CONFNAME="${conf_name}" \
      -t "${IMAGE_NAMESPACE}/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-${conf_name}":"${BWDC_GSUITE_IMAGE_VERSION:-$DEFAULT_BWDC_IMAGE_VERSION_TAG}" \
      -f Containerfile \
      || exit 8
  done
}

# Convenient blurb to let you know how to run the container
usageRun() {
  SECRETS="$( buildPodmanRunSecretsOptions )"
  # In the event just the -u option was specified
  if [ -z "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ]; then
    BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE:-\$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}"
    TYPE_VERSION="\$TYPE_VERSION"
  else
    TYPE_VERSION="BWDC_${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE@U}_IMAGE_VERSION"
    TYPE_VERSION="${!TYPE_VERSION}"
  fi
  cat <<-EOM

	===========================================================================
	  To run the type-conf specific container non-interactively (update CONFNAME):

	    podman run ${SECRETS} --rm ${IMAGE_NAMESPACE}/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-CONFNAME:${TYPE_VERSION} [-c] [-t] [-s] [-h]

	----------------------------------------------------------------------------
	  To run the type-conf specific container interactively (update CONFNAME):

	    podman run ${SECRETS} -it --entrypoint bash --rm ${IMAGE_NAMESPACE}/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-CONFNAME:${TYPE_VERSION}

	===========================================================================
	EOM
}

# Simplistic check for simplistic use case
# USAGE: arrayContains ARRAY SEARCH_ITEM
arrayContains() {
  functionArgCheck "${0}" $# 2

  array="${1}"
  search_item="${2}"

  [[ " ${array[*]} " =~ [[:space:]]${search_item}[[:space:]] ]]
}

while getopts "ht:nru" opt; do
  case "${opt}" in
    "h" )
      # h = help
      usage "${USAGE_HELP}"
      ;;
    "u" )
      # u = usage run statement
      USAGE_RUN=true
      ;;
    "t" )
      # t = type
      if arrayContains "${SUPPORTED_BWDC_SYNCS[*]}" "${OPTARG}" ; then
        BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="${OPTARG}"
      else
        usage 1
      fi
      ;;
    "n" )
      # n = no-cache
      NO_CACHE="--no-cache"
      ;;
    "r" )
      # r = rebuild run stage
      OPTIONAL_REBUILD_BWDC_LOGIN_STAGE="--build-arg OPTIONAL_REBUILD_BWDC_LOGIN_STAGE=\"$( date +%s )\""
      ;;
    * ) usage "${USAGE_ERROR}" ;;
  esac
done

if [ -z "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ] && [ -z "${USAGE_RUN}" ]; then
  usage 3
else
  if ! arrayContains "${SUPPORTED_SECRETS_MANAGERS[*]}" "${SECRETS_MANAGER}"; then
    usage 2
  else
    # Adding this check to allow for just outputting usage below
    if [ -n "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ]; then
      # For the folks who are very specific about when to pull in changes, they
      # can lock bwdc-base to the bitwarden-directory-connector-containers
      # Releases, which may occassionally rewrite tags *gasp*. I'm trying to
      # balance convenience with security and it turns out, that is really
      # difficult. You are shocked, I know.
      # shellcheck disable=SC2153
      [ -n "${USE_BDCC_VERSION_FOR_TYPED}" ] && "${USE_BDCC_VERSION_FOR_TYPED}" && BWDC_VERSION="${BDCC_VERSION}"

      # Typed image defaults
      DEFAULT_BWDC_IMAGE_VERSION_TAG="${BWDC_VERSION}-0"

      case "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" in
        "gsuite" ) buildGsuite ;;
        * ) usage "${USAGE_ERROR}" ;;
      esac
    fi

    [ -n "${USAGE_RUN}" ] && usageRun
    exit 0
  fi
fi
