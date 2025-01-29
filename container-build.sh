#!/bin/bash

# TODO convert to compose file?

# Constants
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
SUPPORTED_BWDC_SYNCS=( gsuite )
SUPPORTED_SECRETS_MANAGERS=( podman env )
# Source conf file with versions
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/versions.conf"
DEFAULT_BWDC_VERSION="${BWDC_VERSION}"
DEFAULT_IMAGE_NAMESPACE="hdub-tech"

# Configurable args
BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE=
BASE_ONLY=
SECRETS_MANAGER="env"
IMAGE_NAMESPACE="${DEFAULT_IMAGE_NAMESPACE}"
NO_CACHE=
OPTIONAL_REBUILD_BWDC_LOGIN_STAGE=

USAGE_HELP=0
USAGE_ERROR=255
usage() {
  cat <<EOM
  USAGE:
    ${SCRIPT_NAME} -t BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE|-o [-s SECRETS_MANAGER] [-b BWDC_VERSION] [-i IMAGE_NAMESPACE] [-n] [-r]

   - At least one method flag is required:
     - Use -t BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE for the "config file"
       method, where BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE is one of:
       ${SUPPORTED_BWDC_SYNCS[*]}
     - Use -o for the "bring your own data.json" method
   - SECRETS_MANAGER is one of: ${SUPPORTED_SECRETS_MANAGERS[*]} (Not needed with -o)
     Note: "env" (default) indicates that the secrets are already exported to the environment.
   - BWDC_VERSION (default=${DEFAULT_BWDC_VERSION}) is X.Y.Z format (no leading v!) and one of: https://github.com/bitwarden/directory-connector/releases
   - IMAGE_NAMESPACE (default=${DEFAULT_IMAGE_NAMESPACE}) - For type specific images only,
     you can specify the namespace portion of the tag (in case you want to push
     these to your own container registry).
   - Use "-n" to build all container images without cache (--no-cache)
   - Use "-r" to rebuild the final run stage of the type specific container (allows you to test login)

EOM

  # If usage was called without args, exit as error
  RC="${1:-USAGE_ERROR}"
  exit "${RC}"
}

# 1: functionName, 2: numArgsActual, 3: numArgsExpected
functionArgCheck() {
  if [ "${2}" -lt "${3}" ]; then
    echo "${1} requires at least ${3} args"
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
      echo "${psecret} doesn't exist in podman local storage"
      exit 5
    fi
  done
}

# env secrets SHOULD already be exported in this env and this confirms it
confirmEnvSecrets() {
  functionArgCheck "${0}" $# 1

  for env in "$@"; do
    if [ -z "${!env}" ]; then  # The ! allows Indirect Ref to env var
      echo "SECRETS_MANAGER=env but ${env} not exported in this environment"
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

# Build common base image
buildBase() {
  podman build ${NO_CACHE} \
    --build-arg BWDC_BASE_IMAGE_VERSION="${BWDC_BASE_IMAGE_VERSION}" \
    --build-arg BWDC_VERSION="${BWDC_VERSION}" \
    -t hdub-tech/bwdc-base:"${BWDC_BASE_IMAGE_VERSION}" \
    -f Containerfile \
    || exit 9
}

# Build gsuite sync image(s)
buildGsuite() {
  exportSecrets bw_clientid bw_clientsecret

  cd "${SCRIPT_DIR}"/"${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" || exit 1

  # Exit if no conf files
  ! ls ./*.conf && exit 7

  for conf in *.conf; do
    conf_name="$( basename "${conf%.conf}" )"
    # shellcheck disable=SC2086
    podman build ${NO_CACHE} \
      ${OPTIONAL_REBUILD_BWDC_LOGIN_STAGE} \
      --build-arg-file="${conf}" \
      --secret=id=bw_clientid,env=BW_CLIENTID \
      --secret=id=bw_clientsecret,env=BW_CLIENTSECRET \
      --build-arg BWDC_BASE_IMAGE_VERSION="${BWDC_BASE_IMAGE_VERSION}" \
      --build-arg BWDC_GSUITE_IMAGE_VERSION="${BWDC_GSUITE_IMAGE_VERSION}" \
      -t "${IMAGE_NAMESPACE}/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-${conf_name}":"${BWDC_GSUITE_IMAGE_VERSION}" \
      -f Containerfile \
      || exit 8
  done
}

# Convenient blurb to let you know how to run the container
usageRun() {
  declare -a SECRETS
  case "${SECRETS_MANAGER}" in
    "env" )
      [ -n "${BASE_ONLY}" ] && BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="\$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE"
      SECRETS+=("--env-file ${SCRIPT_DIR}/${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}/env.vars")
      ;;
    "podman" )
      SECRETS+=("--secret=bw_clientid,type=env,target=BW_CLIENTID")
      SECRETS+=("--secret=bw_clientsecret,type=env,target=BW_CLIENTSECRET")
      [[ "gsuite" == "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ]] && SECRETS+=("--secret=bw_gsuitekey,type=env,target=BW_GSUITEKEY")
      ;;
  esac

  cat <<-BASE
	===========================================================================
	  To run the generic base container using your own data.json file
	  non-interactively, mount the directory containing your data.json file
	  ==> THIS WILL RESULT IN DATA.JSON BEING MODIFIED (bwdc behavior). <==

	    podman run ${SECRETS[*]} --rm --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_BASE_IMAGE_VERSION} [-c] [-t] [-s] [-h]

	----------------------------------------------------------------------------
	  To run the generic base container using your own data.json file
	  interactively, mount the directory containing your data.json file
	  ==> THIS WILL RESULT IN DATA.JSON BEING MODIFIED IF YOU USE bwdc <==

	    podman run ${SECRETS[*]} -it --rm --entrypoint bash --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_BASE_IMAGE_VERSION}
	BASE

  if [ -z "${BASE_ONLY}" ]; then
    TYPE_VERSION="BWDC_${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE@U}_IMAGE_VERSION"
    cat <<-TYPE

	----------------------------------------------------------------------------
	  To run the type-conf specific container non-interactively (update CONFNAME):

	    podman run ${SECRETS[*]} --rm ${IMAGE_NAMESPACE}/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-CONFNAME:${!TYPE_VERSION} [-c] [-t] [-s] [-h]

	----------------------------------------------------------------------------
	  To run the type-conf specific container interactively (update CONFNAME):

	    podman run ${SECRETS[*]} -it --entrypoint bash --rm ${IMAGE_NAMESPACE}/bwdc-${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}-CONFNAME:${!TYPE_VERSION}

	TYPE
  fi
  echo "==========================================================================="
}

# Simplistic check for simplistic use case
# USAGE: arrayContains ARRAY SEARCH_ITEM
arrayContains() {
  functionArgCheck "${0}" $# 2

  array="${1}"
  search_item="${2}"

  [[ " ${array[*]} " =~ [[:space:]]${search_item}[[:space:]] ]]
}

while getopts "ht:os:b:i:nr" opt; do
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
    "o" )
      # = only build base
      BASE_ONLY=true ;;
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
    "r" )
      # r = rebuild run stage
      OPTIONAL_REBUILD_BWDC_LOGIN_STAGE="--build-arg OPTIONAL_REBUILD_BWDC_LOGIN_STAGE=\"$( date +%s )\""
      ;;
    "b" )
      # b = BWDC version
      BWDC_VERSION="${OPTARG}"
      ;;
    "i" )
      # i = Image Namespace for tag
      IMAGE_NAMESPACE="${OPTARG}"
      ;;
    * ) usage "${USAGE_ERROR}" ;;
  esac
done

if [ -z "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ] && [ -z "${BASE_ONLY}" ]; then
  usage 3
else
  if [ -z "${SECRETS_MANAGER}" ]; then
    usage 10
  else
    if [ -n "${BASE_ONLY}" ]; then
      buildBase
    else
      case "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" in
        "gsuite" ) buildGsuite ;;
        * ) usage "${USAGE_ERROR}" ;;
      esac
    fi

    usageRun
  fi
fi
