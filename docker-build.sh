#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
SUPPORTED_BWDC_SYNCS=( gsuite )
SUPPORTED_SECRETS_MANAGERS=( podman preset )

BWDC_VERSION=2024.10.0
BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE=
SECRETS_MANAGER=
NO_CACHE=

USAGE_HELP=0
USAGE_ERROR=255
usage() {
  cat <<EOM
  USAGE:
    ${SCRIPT_NAME} -t BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE -s SECRETS_MANAGER [-n]

   - BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE is one of: ${SUPPORTED_BWDC_SYNCS[*]}
   - SECRETS_MANAGER is one of: ${SUPPORTED_SECRETS_MANAGERS[*]}
     Note: "preset" indicates that the secrets are already exported to the environment.
   - Use "-n" to build all Docker images without cache (--no-cache)

EOM

  # If usage was called without args, exit as error
  RC="${1:-USAGE_ERROR}"
  exit "${RC}"
}

# uppercase all arguments
uppercase() {
  if [ "$#" -lt 1 ]; then
    echo "uppercase requires at least 1 arg"
    exit 4
  fi

  echo "$@" | tr '[:lower:]' '[:upper:]'
}

# extract the specified podman secrets to a corresponding environment var
exportPodmanSecrets() {
  for psecret in "$@" ; do
    if podman secret exists "${psecret}"; then
      declare -a FILE_AND_ID
      # Select the file with the specified secret as well as its Hex ID
      mapfile -t FILE_AND_ID < <( podman secret inspect "${psecret}" | jq -r '.[0].Spec.Driver.Options.path, .[0].ID' )
      # Extract the encoded secret from its file using its Hex ID
      ENCODED=$( jq -r --arg secretid "${FILE_AND_ID[1]}" '.[$secretid]' "${FILE_AND_ID[0]}"/secretsdata.json )
      SECRET_KEY="$( uppercase "${psecret}" )"
      # Yeah it really is that terrible
      SECRET_VALUE="$( echo "${ENCODED}" | base64 -d )"
      export "${SECRET_KEY}"="${SECRET_VALUE}"
    else
      echo "${psecret} doesn't exist in podman local storage"
      exit 5
    fi
  done
}

# Preset secrets SHOULD already be exported in this env and this confirms it
confirmPresetSecrets() {
  for preset in "$@"; do
    if [ -z "${!preset}" ]; then  # The ! allows Indirect Ref to env var
      echo "Please export ${preset} if using SECRETS_MANAGER=preset"
      exit 6
    fi
  done
}

# Generic export secrets function with error handling, calls exports by type
exportSecrets() {
  if [ "$#" -lt 1 ]; then
    echo "USAGE: ${0} secretid1 [secretid2 ... secretidN]"
    exit 7
  fi

  case "${SECRETS_MANAGER}" in
    "podman" ) exportPodmanSecrets "$@" ;;
    "preset" )
      # shellcheck disable=SC2048,SC2086
      confirmPresetSecrets ${*@U} ;;
  esac
}

# Build common base image
buildBase() {
  exportSecrets bw_clientid bw_clientsecret

  podman build ${NO_CACHE} \
    --secret=id=bw_clientid,env=BW_CLIENTID \
    --secret=id=bw_clientsecret,env=BW_CLIENTSECRET \
    -t hdub-tech-bwdc-base:"${BWDC_VERSION}" -f Dockerfile
}

# Build gsuite sync image
buildGsuite() {
  buildBase
  exportSecrets bw_orguuid bw_key

  cd "${SCRIPT_DIR}"/"${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}"
  podman build ${NO_CACHE} \
    --build-arg-file=argfile.conf \
    --secret=id=bw_orguuid,env=BW_ORGUUID \
    --secret=id=bw_key,env=BW_KEY \
    -t hdub-tech-bwdc-"${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}":"${BWDC_VERSION}" -f Dockerfile
}

# Convenient blurb to let you know how to run the container
usageRun() {
  declare -a SECRETS
  SECRETS+=("--secret=bw_clientid,type=env,target=BW_CLIENTID")
  SECRETS+=("--secret=bw_clientsecret,type=env,target=BW_CLIENTSECRET")

  cat <<EOM
    To run non-interactively:
      podman run ${SECRETS[*]} localhost/hdub-tech-bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}:${BWDC_VERSION}

    To run interactively:
      podman run ${SECRETS[*]} -it --entrypoint bash localhost/hdub-tech-bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}:${BWDC_VERSION}
EOM
}

# Simplistic check for simplistic use case
arrayContains() {
  if [ "$#" -ne 2 ]; then
    echo "USAGE: ${0} ARRAY SEARCH_ITEM"
    exit 8
  fi

  array="${1}"
  search_item="${2}"

  [[ " ${array[*]} " =~ [[:space:]]${search_item}[[:space:]] ]]
}

while getopts "ht:s:n" opt; do
  case "${opt}" in
    "h" )
      # h = help
      usage "${USAGE_HELP}" ;;
    "t" )
      # t = type
      if arrayContains "${SUPPORTED_BWDC_SYNCS[*]}" "${OPTARG}" ; then
        BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="${OPTARG}"
      else
        usage 1
      fi
      ;;
    "s" )
      # s = secret manager
      if arrayContains "${SUPPORTED_SECRETS_MANAGERS[*]}" "${OPTARG}" ; then
        SECRETS_MANAGER="${OPTARG}"
      else
        usage 2
      fi
      ;;
    "n" )
      # n = no-cache
      NO_CACHE="--no-cache" ;;
    * ) usage "${USAGE_ERROR}" ;;
  esac
done

if [ -z "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ] || [ -z "${SECRETS_MANAGER}" ]; then
  usage 3
else
  case "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" in
    "gsuite" ) buildGsuite ;;
  esac

  usageRun
fi