#!/bin/bash

# Constants
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
DEFAULT_PROJECT_CONFS_DIR="$( cd "${SCRIPT_DIR}/../" && pwd )"
SUPPORTED_BWDC_TYPES=( gsuite )
SUPPORTED_MODES=( build config test sync )
REQUIRED_PACKAGES=( podman )
ROOT_IMAGE_NAME="localhost/hdub-tech/bwdc"
MINIMUM_PODMAN_VERSION="4.5.0"

# Configurable args
PROJECT_CONFS_DIR="${DEFAULT_PROJECT_CONFS_DIR}"
MODE=
SKIP_PREREQS=
# TODO: Support specifying bwdc version
BWDC_VERSION="2024.10.0"
# TODO: SECRETS_MANAGER flag
SECRETS_MANAGER="env"

usage() {
   cat <<EOM
  DESCRIPTION:
    A script which will build multiple images of multiple types as a sort
    of one stop shop for doing all of your bwdc syncs (or even just test).
    This github project should be a submodule of your project of confs.
    This script is intended to be run in a Continuous Integration system.
>>> (!) WARNING: THIS SCRIPT WILL INSTALL REQUIRED PACKAGES UNLESS RUN WITH -s (!) <<<

  USAGE:
    ${0} -m build|config|test|sync [-p PROJECT_CONFS_DIR] [-s]

  Where:
    * -m MODE is one of:
      * build: Builds one container image per conf per supported bwdc directory type
        (Supported: ${SUPPORTED_BWDC_TYPES[@]})
      * config: Builds the above images and runs each container, finishing the
        necessary configuration using the secrets provided
      * test: Does the above build + config and runs "bwdc test"
      * sync: Does the above build + config + test and runs "bwdc sync"
    * PROJECT_CONFS_DIR: The path to your project directory containing subdirs
      for each type of Bitwarden Directory connectors with YOUR configuration
      files. The default (${DEFAULT_PROJECT_CONFS_DIR}) is the directory above
      this script because it is assumed you followed the instructions in the
      README and made the bitwarden-directory-connector-containers as a
      submodule of your project.
    * -s: Skip installing pre-reqs. Useful on non-apt systems which already have
      pre-reqs installed or systems which needed podman installed from source.
EOM
  exit "${1}"
}

# $1 = level, $@ = message
message() {
  level=$1
  shift
  echo "[${SCRIPT_NAME}] ${level}: $*"
}

# Requirements: podman>=4.5.0
preReqs() {
  if ! which apt; then
    cat <<EOM
      ${0} currently only supports apt based systems for pre-req installation.
      Please install the pre-reqs manually and re-run script with -s flag.
      Pre-reqs: [${REQUIRED_PACKAGES[@]}]
EOM
    exit 4
  fi

  # If conf files exist and are modified, prefer the old and don't prompt
  dpkg_options=( -o Dpkg::Options::="--force-confold" )
  (sudo apt-get update && \
     sudo apt-get upgrade --assume-yes "${dpkg_options[@]}" && \
     sudo apt-get install --assume-yes "${dpkg_options[@]}" "${REQUIRED_PACKAGES[@]}") || exit 5

  # Check if podman is installed and the minimum required version
  if which podman; then
    podman_version="$( podman --version | cut -d' ' -f3 )"
    printf -v expected_sort '%s\n%s' "${MINIMUM_PODMAN_VERSION}" "${podman_version}"
    if [[ "${expected_sort}" != "$( sort -V <<< "${expected_sort}")" ]]; then
      cat <<EOM
        The installed version of podman (${podman_version}) is not the
        minimum version required (${MINIMUM_PODMAN_VERSION}). This is likely
        due to the repository containing an older version than is required by
        this peoject, which means you will need to build podman from source.
        After doing that, please re-run this script with "-s" to skip the
        dependency installation step.
EOM
      exit 6
    fi
  fi
}

# Copy custom configs
copyConfigs() {
  for type in "${SUPPORTED_BWDC_TYPES[@]}"; do
    if [ -d "${PROJECT_CONFS_DIR}/${type}" ]; then
      # Copy over custom configs
      cp "${PROJECT_CONFS_DIR}"/"${type}"/*.conf "${SCRIPT_DIR}"/"${type}"/ || exit 7
    fi
  done
}

# Build the container images for this type (builds all confs for all types)
buildImages() {
  for type in "${SUPPORTED_BWDC_TYPES[@]}"; do
    if [ -d "${PROJECT_CONFS_DIR}/${type}" ]; then
      "${SCRIPT_DIR}/container-build.sh" -t "${type}" -s "${SECRETS_MANAGER}" -b "${BWDC_VERSION}" || exit 9
    fi
  done

  podman image ls "${ROOT_IMAGE_NAME}"*
}

# Run each container in the mode specified
runContainers() {
  for type in "${SUPPORTED_BWDC_TYPES[@]}"; do
    if [ -d "${PROJECT_CONFS_DIR}/${type}" ]; then
      message "INFO" "Running images of type [${type}]"
      for conf in "${SCRIPT_DIR}/${type}"/*.conf; do
        conf_name="$( basename "${conf%.conf}" )"
	message "INFO" "Running conf [${conf_name}] in mode [${MODE}]"
        # Since no latest tag, use image id of the most recently created image
        image_id="$( podman image ls "${ROOT_IMAGE_NAME}-${type}-${conf_name}" --sort created --quiet )"
        podman run --env-file "${SCRIPT_DIR}/${type}/env.vars" "${image_id}" "${MODE}" || exit 10
      done
    else
      message "INFO" "No images of type [${type}] in [${PROJECT_CONFS_DIR}]...skipping"
    fi
  done
}

while getopts "p:m:sh" opt; do
  case "${opt}" in
    "p" )
      # p = project dir
      [ ! -d "${OPTARG}" ] && message "ERROR" "Directory does not exist: ${OPTARG}" && usage 8
      PROJECT_CONFS_DIR=$( cd "${OPTARG}" && pwd )
      ;;
    "m" )
      # m = mode
      [[ ! " ${SUPPORTED_MODES[*]} " =~ [[:space:]]${OPTARG}[[:space:]] ]] && usage 1
      MODE="${OPTARG}"
      ;;
    "s" )
      # s = skip pre-req installation
      SKIP_PREREQS="true"
      ;;
    "h" )
      # h = help
      usage 0 ;;
    * ) usage 2 ;;
  esac
done

if [ -z "${MODE}" ]; then
  usage 3
else
  # If -s wasn't specified, install pre-reqs
  [ -z "${SKIP_PREREQS}" ] && preReqs

  # Only copy the configs if PROJECT_CONFS_DIR is different from SCRIPT_DIR
  [ "${SCRIPT_DIR}" != "${PROJECT_CONFS_DIR}" ] && copyConfigs

  # Always build images
  buildImages

  # Run containers in MODE, unless MODE==build
  [ "build" != "${MODE}" ] && runContainers
fi
