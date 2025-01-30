#!/bin/bash

# Constants
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
# Source conf file with default versions
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/defaults.conf"
DEFAULT_BWDC_VERSION="${BWDC_VERSION}"
DEFAULT_IMAGE_NAMESPACE="hdub-tech"

# Configurable args
MAKE_IT_SO=
NO_CACHE=
IMAGE_NAMESPACE="${DEFAULT_IMAGE_NAMESPACE}"
# If a custom conf, source it for overrides
# shellcheck disable=SC1091
[ -e "${SCRIPT_DIR}/custom.conf" ] && . "${SCRIPT_DIR}/custom.conf"

USAGE_HELP=0
USAGE_ERROR=255
usage() {
  cat <<EOM
  USAGE:
    ${SCRIPT_NAME} -c [-b BWDC_VERSION] [-n] [-i IMAGE_NAMESPACE]

   - -c is the Confirmation flag that you actually meant to execute the script
   - BWDC_VERSION (default=${DEFAULT_BWDC_VERSION}) is X.Y.Z format (no leading v!) and one of: https://github.com/bitwarden/directory-connector/releases
   - Use "-n" to build container image without cache (--no-cache)
   - IMAGE_NAMESPACE (default=${DEFAULT_IMAGE_NAMESPACE}). You can specify the
     namespace portion of the tag (in case you want to push this to your own
     container registry).

EOM

  # If usage was called without args, exit as error
  RC="${1:-USAGE_ERROR}"
  exit "${RC}"
}

# Build common base image
buildBase() {
  podman build ${NO_CACHE} \
    --build-arg BWDC_BASE_IMAGE_VERSION="${BWDC_BASE_IMAGE_VERSION}" \
    --build-arg BWDC_VERSION="${BWDC_VERSION}" \
    -t "${IMAGE_NAMESPACE}"/bwdc-base:"${BWDC_BASE_IMAGE_VERSION}" \
    -f Containerfile \
    || exit 1
}

# Convenient blurb to let you know how to run the container
usageRun() {

  # shellcheck disable=SC1091
  . "${SCRIPT_DIR}"/functions.sh
  export BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE="\$BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE"
  export SECRETS_MANAGER="env"
  SECRETS="$( buildPodmanRunSecretsOptions )"

  cat <<-EOM
	===========================================================================
	  To run the generic base container using your own data.json file
	  NON-INTERACTIVELY, mount the directory containing your data.json file
	  ==> THIS WILL RESULT IN DATA.JSON BEING MODIFIED (bwdc behavior). <==

	  Published version:
	    podman run ${SECRETS} --rm --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_BASE_IMAGE_VERSION} [-c] [-t] [-s] [-h]

	  Local version:
	    podman run ${SECRETS} --rm --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ${IMAGE_NAMESPACE}/bwdc-base:${BWDC_BASE_IMAGE_VERSION} [-c] [-t] [-s] [-h]
	----------------------------------------------------------------------------
	  To run the generic base container using your own data.json file
	  INTERACTIVELY, mount the directory containing your data.json file
	  ==> THIS WILL RESULT IN DATA.JSON BEING MODIFIED IF YOU USE bwdc <==

	  Published version:
	    podman run ${SECRETS} -it --rm --entrypoint bash --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ghcr.io/hdub-tech/bwdc-base:${BWDC_BASE_IMAGE_VERSION}

	  Local version:
	    podman run ${SECRETS} -it --rm --entrypoint bash --volume /PATH/TO/YOUR/DATA-JSON-DIR:/bwdc/.config/Bitwarden\ Directory\ Connector --userns=keep-id ${IMAGE_NAMESPACE}/bwdc-base:${BWDC_BASE_IMAGE_VERSION}

	===========================================================================
	EOM
}

while getopts "chb:ni:" opt; do
  case "${opt}" in
    "h" )
      # h = help
      usage "${USAGE_HELP}" ;;
    "c" )
      # confirmed
      MAKE_IT_SO=true
      ;;
    "b" )
      # b = BWDC version
      BWDC_VERSION="${OPTARG}" ;;
    "n" )
      # n = no-cache
      NO_CACHE="--no-cache" ;;
    "i" )
      # i = Image Namespace for tag
      IMAGE_NAMESPACE="${OPTARG}" ;;
    * ) usage "${USAGE_ERROR}" ;;
  esac
done

if [ -z "${MAKE_IT_SO}" ]; then
  usage 2
else
  buildBase
  usageRun
fi
