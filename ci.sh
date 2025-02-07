#!/bin/bash

# Constants
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
DEFAULT_PROJECT_CONFS_DIR="$( cd "${SCRIPT_DIR}/../" && pwd )"
SUPPORTED_BWDC_TYPES=( gsuite )
SUPPORTED_MODES=( config test sync )
REQUIRED_PACKAGES=( podman )
MINIMUM_PODMAN_VERSION="4.5.0"

# Configurable args
PROJECT_CONFS_DIR="${DEFAULT_PROJECT_CONFS_DIR}"
MODE=
SKIP_PREREQS=
IMAGE_NAMESPACE=

usage() {
   cat <<EOM
  DESCRIPTION:
    A script which will build multiple images of multiple types as a sort
    of one stop shop for doing all of your bwdc syncs (or even just test).
    This github project should be a submodule of your project of confs.
    This script was designed with simplification for CI and workflows in mind.

>>> (!) WARNING: THIS SCRIPT WILL INSTALL REQUIRED PACKAGES UNLESS RUN WITH -s (!) <<<

  USAGE:
    ${0} -b|-r MODE [-p PROJECT_CONFS_DIR] [-s]

  Where:
    * -b and/or -r MODE is specified.
    * -b: Builds all of your typed containers. You can skip this if you already
      have the images built and published somewhere accessible by this script.
    * -r MODE is one of:
      * config: Runs each container, finishing the necessary configuration using
        the secrets provided
      * test: Does the above config AND runs "bwdc test"
      * sync: Does the above config + test AND runs "bwdc sync"
    * PROJECT_CONFS_DIR: The path to your project directory containing subdirs
      for each type of Bitwarden Directory connectors with YOUR configuration
      files. The default (${DEFAULT_PROJECT_CONFS_DIR}) is the directory above
      this script because it is assumed the bitwarden-directory-connector-containers
      project is a submodule of your project.
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
  # Copy over the overrides conf file, if it exists
  if [ -e "${PROJECT_CONFS_DIR}/custom.conf" ]; then
    cp "${PROJECT_CONFS_DIR}/custom.conf" "${SCRIPT_DIR}/" || exit 11
  fi

  # Copy over the type specific confs, if the type dir exists
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
      "${SCRIPT_DIR}/build-typed-images.sh" -t "${type}" || exit $(($?+20))
    fi
  done

  podman image ls "${IMAGE_NAMESPACE}"/*
}

# Run each container in the mode specified
runContainers() {
  ENTRYPOINT_OPTS=
  case "${MODE}" in
    "config" ) ENTRYPOINT_OPTS="-c" ;;
    "test"   ) ENTRYPOINT_OPTS="-c -t" ;;
    "sync"   ) ENTRYPOINT_OPTS="-c -t -s" ;;
  esac

  for type in "${SUPPORTED_BWDC_TYPES[@]}"; do
    if [ -d "${PROJECT_CONFS_DIR}/${type}" ]; then
      message "INFO" "Running images of type [${type}]"
      for conf in "${SCRIPT_DIR}/${type}"/*.conf; do
        conf_name="$( basename "${conf%.conf}" )"
        type_version="BWDC_${type@U}_IMAGE_VERSION"
        #TODO Add an error handler for this
        image_tag="$( grep "^${type_version}" "${conf}" | cut -d= -f2 )"
        message "INFO" "Running conf [${conf_name}] version [${image_tag}] in mode [${MODE}]"
        # shellcheck disable=SC2086
        podman run --env-file "${SCRIPT_DIR}/${type}/env.vars" --rm "${IMAGE_NAMESPACE}/bwdc-${type}-${conf_name}":"${image_tag}" ${ENTRYPOINT_OPTS} || exit 10
      done
    else
      message "INFO" "No images of type [${type}] in [${PROJECT_CONFS_DIR}]...skipping"
    fi
  done
}

while getopts "bp:r:sh" opt; do
  case "${opt}" in
    "b" )
      # b = build typed images
      BUILD_TYPED_IMAGES="true"
      ;;
    "p" )
      # p = project dir
      [ ! -d "${OPTARG}" ] && message "ERROR" "Directory does not exist: ${OPTARG}" && usage 8
      PROJECT_CONFS_DIR=$( cd "${OPTARG}" && pwd )
      ;;
    "r" )
      # r = run containers
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

if [ -z "${BUILD_TYPED_IMAGES}" ] && [ -z "${MODE}" ]; then
  usage 3
else
  # If -s wasn't specified, install pre-reqs
  [ -z "${SKIP_PREREQS}" ] && preReqs

  # Only copy the configs if PROJECT_CONFS_DIR is different from SCRIPT_DIR
  [ "${SCRIPT_DIR}" != "${PROJECT_CONFS_DIR}" ] && copyConfigs

  # Grab our IMAGE_NAMESPACE
  # shellcheck disable=SC1091
  . "${SCRIPT_DIR}"/defaults.conf
  # shellcheck disable=SC1091
  [ -e  "${SCRIPT_DIR}"/custom.conf ] && . "${SCRIPT_DIR}"/custom.conf

  # Build typed images, if -b specified
  [ -n "${BUILD_TYPED_IMAGES}" ] && buildImages

  # Run containers in MODE, if -r specified
  [ -n "${MODE}" ] && runContainers
fi
