#!/bin/bash

# Constants / Globals
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
DEFAULT_PROJECT_CONFS_DIR="$( cd "${SCRIPT_DIR}/../" && pwd )"
SUPPORTED_BWDC_TYPES=( gsuite )
SUPPORTED_MODES=( config test sync )
MINIMUM_PODMAN_VERSION="4.5.0"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}"/functions.sh
CI_PODMAN_AUTHORIZED=

# Configurable args
PROJECT_CONFS_DIR="${DEFAULT_PROJECT_CONFS_DIR}"
BUILD_TYPED_IMAGES=
PUSH_TYPED_IMAGES=
MODE=
SKIP_PREREQS=
IMAGE_NAMESPACE=
REGISTRY=

usage() {
   cat <<EOM

  DESCRIPTION:
    A script which will build and/or push multiple images of multiple types as a
    one stop shop for doing all of your bwdc syncs (or even just test).
    This github project should be a submodule of your project of confs.
    This script was designed with simplification for CI and workflows in mind.

>>> (!) WARNING: THIS SCRIPT WILL INSTALL REQUIRED PACKAGES UNLESS RUN WITH -s (!) <<<

  USAGE:
    ${0} -b|-p|-r MODE [-d PROJECT_CONFS_DIR] [-s]

  Where:
    * At least one of -b and/or -p and/or -r MODE is specified.
    * -b: Builds all of your typed containers. You can skip this if you already
      have the images built and published somewhere accessible by this script.
    * -p: Push all \$IMAGE_NAMESPACE/bwdc-* images. If you are not already
      logged into your container registry, set the REGISTRY_USER and
      REGISTRY_PASSWORD environment variables and it will be done for you.
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

# Requirements: podman>=4.5.0
preReqs() {
  # Protection from podman installed from source, which apt will not detect
  if ! which podman >/dev/null; then
    if ! which apt >/dev/null; then
      cat <<EOM
        ${0} currently only supports apt based systems for pre-req installation.
        Please install the pre-reqs manually and re-run script with -s option.
        Pre-reqs: [podman]
EOM
      exit 4
    fi

    # If conf files exist and are modified, prefer the old and don't prompt
    dpkg_options=( -o Dpkg::Options::="--force-confold" )
    (sudo apt-get update && \
       sudo apt-get upgrade --assume-yes "${dpkg_options[@]}" && \
       sudo apt-get install --assume-yes "${dpkg_options[@]}" podman) || exit 5
  fi

  # Check if podman is installed and the minimum required version
  if which podman >/dev/null; then
    podman_version="$( podman --version | cut -d' ' -f3 )"
    printf -v expected_sort '%s\n%s' "${MINIMUM_PODMAN_VERSION}" "${podman_version}"
    if [[ "${expected_sort}" != "$( sort -V <<< "${expected_sort}")" ]]; then
      cat <<EOM
        The installed version of podman (${podman_version}) is not the
        minimum version required (${MINIMUM_PODMAN_VERSION}). This is likely
        due to the repository containing an older version than is required by
        this project, which means you will need to build podman from source.
        After doing that, please re-run this script with "-s" to skip the
        dependency installation step.
EOM
      exit 6
    else
      echo "Installed version of podman (${podman_version}) is >= minimum (${MINIMUM_PODMAN_VERSION})...continuing"
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

podmanLogin () {
  # If not logged in, attempt to login to registry with env variables
  if ! podman login --get-login "${REGISTRY}" &>/dev/null; then
    message "${SCRIPT_NAME}" "WARN" "Not logged into ${REGISTRY}. Attempting login using \${REGISTRY_USER} and \${REGISTRY_PASSWORD} environment variables"

    set +x  # Make extra sure no output
    if [ -n "${REGISTRY_USER}" ] && [ -n "${REGISTRY_PASSWORD}" ]; then
      echo "${REGISTRY_PASSWORD}" | podman login "$REGISTRY" --username "${REGISTRY_USER}" --password-stdin && CI_PODMAN_AUTHORIZED=true
    fi

    if ! podman login --get-login "${REGISTRY}" &>/dev/null; then
      message "${SCRIPT_NAME}" "ERROR" "podman login failed. Please run podman login manually, or set REGISTRY_USER and REGISTRY_PASSWORD environment variables and re-run this script"
      usage 9
    fi
  fi
}

# Logout, but only if this script was the one to login
podmanLogout() {
  [ -n "${CI_PODMAN_AUTHORIZED}" ] && podman logout "${REGISTRY}"
}

# Push all IMAGE_NAMESPACE/bwdc-* images to registry
pushImages() {
  if [ "localhost" == "${REGISTRY}" ]; then
    message "${SCRIPT_NAME}" "WARN" "IMAGE_NAMESPACE is localhost - skipping push to registry!"
  else
    podmanLogin

    # Should be logged in, get all relevant images and push
    image_prefix="${IMAGE_NAMESPACE}"/bwdc
    bwdc_images="$( podman image ls --filter=reference="${image_prefix}-*" --noheading --format "table {{.Repository}}:{{.Tag}}" )"
    declare -a ci_push_failures
    if [ -n "${bwdc_images}" ]; then
      for bwdc_image in ${bwdc_images}; do
        # podman image ls will return images which do NOT match the reference
        # if they are tagged from an image that DOES match the reference. This
        # prevents incidentals
        if [ "${bwdc_image#"$image_prefix"}" != "${bwdc_image}" ]; then
          message "${SCRIPT_NAME}" "INFO" "Pushing [${bwdc_image}] to [${REGISTRY}]"
	  podman push "${bwdc_image}" || ci_push_failures+=("${bwdc_image} ")
        else
          message "${SCRIPT_NAME}" "WARN" "[${bwdc_image}] not prefixed with [${image_prefix}]...skipping push."
        fi
      done
    else
      message "${SCRIPT_NAME}" "WARN" "No [${image_prefix}-*] images to push!"
    fi

    podmanLogout

    # Exit with error if we had push failures
    if [ "${#ci_push_failures}" -gt 0 ]; then
      message "${SCRIPT_NAME}" "ERROR" "Errors pushing the following images: ${ci_push_failures[*]}"
      exit 12
    fi
  fi
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
      message "${SCRIPT_NAME}" "INFO" "Running images of type [${type}]"
      for conf in "${SCRIPT_DIR}/${type}"/*.conf; do
        conf_name="$( basename "${conf%.conf}" )"
        type_version="BWDC_${type@U}_IMAGE_VERSION"
        #TODO Add an error handler for this
        image_tag="$( grep "^${type_version}" "${conf}" | cut -d= -f2 )"
        message "${SCRIPT_NAME}" "INFO" "Running conf [${conf_name}] version [${image_tag}] in mode [${MODE}]"
        # shellcheck disable=SC2086
        podman run --env-file "${SCRIPT_DIR}/${type}/env.vars" --rm "${IMAGE_NAMESPACE}/bwdc-${type}-${conf_name}":"${image_tag}" ${ENTRYPOINT_OPTS} || exit 10
      done
    else
      message "${SCRIPT_NAME}" "INFO" "No images of type [${type}] in [${PROJECT_CONFS_DIR}]...skipping"
    fi
  done
}

while getopts "bpd:r:sh" opt; do
  case "${opt}" in
    "b" )
      # b = build typed images
      BUILD_TYPED_IMAGES="true"
      ;;
    "p" )
      # p = push images
      PUSH_TYPED_IMAGES="true"
      ;;
    "d" )
      # d = dir for project confs
      [ ! -d "${OPTARG}" ] && message "${SCRIPT_NAME}" "ERROR" "Directory does not exist: ${OPTARG}" && usage 8
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

if [ -z "${BUILD_TYPED_IMAGES}" ] && [ -z "${PUSH_TYPED_IMAGES}" ] && [ -z "${MODE}" ]; then
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
  REGISTRY="${IMAGE_NAMESPACE%/*}"

  # Build typed images, if -b specified
  [ -n "${BUILD_TYPED_IMAGES}" ] && buildImages

  # Push IMAGE_NAMESPACE/bwdc-* images, if -p specified
  [ -n "${PUSH_TYPED_IMAGES}" ] && pushImages

  # Run containers in MODE, if -r specified
  [ -n "${MODE}" ] && runContainers

  exit 0
fi
