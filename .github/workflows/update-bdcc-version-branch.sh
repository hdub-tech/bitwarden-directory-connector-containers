#!/bin/bash

# Constants / Globals
SCRIPT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
SCRIPT_NAME="$( basename "${0}" )"
PROJECT_DIR=$( cd "${SCRIPT_DIR}/../../" && pwd )
SUPPORTED_BWDC_TYPES=( gsuite )
FILES_TO_UPDATE=( defaults.conf gsuite/argfile.conf.template docs/config-files.md )
# shellcheck disable=SC1091
. "${PROJECT_DIR}"/functions.sh

# Configurable args
NEW_BDCC_VERSION=
RELEASE_BRANCH=

usage() {
   cat <<EOM

  DESCRIPTION:
    A script which will create a release branch, sed update the BDCC_VERSION in
    the relevant files, then run git add, git commit and git push. Current
    files being updated:
$( for file in "${FILES_TO_UPDATE[@]}"; do echo "    - $file"; done; )

  USAGE:
    ${0} -v NEW_BDCC_VERSION [-h]

  Where:
    * -h: Displays this help statement
    * -v NEW_BDCC_VERSION: REQUIRED. The new version number of bdcc. Do NOT
     include the leading 'v'
EOM
  exit "${1}"
}

sedUpdates() {
  # Update BDCC_VERSION in defaults.conf
  sed -i'' "/^BDCC_VERSION/s|=.*|=${NEW_BDCC_VERSION}|" "${PROJECT_DIR}/defaults.conf" || exit 3
  
  # Update BWDC_$TYPE_IMAGE_VERSION argfile.conf.template
  for type in "${SUPPORTED_BWDC_TYPES[@]}"; do
    sed -i'' "/IMAGE_VERSION=/s|=.*-|=${NEW_BDCC_VERSION}-|" "${PROJECT_DIR}/${type}/argfile.conf.template" || exit 4
  done
  
  # Update git blurbs in config-files.md
  sed -i'' "/^git checkout/s|v[0-9\.]*|v${NEW_BDCC_VERSION}|" "${PROJECT_DIR}/docs/config-files.md" || exit 5
  sed -i'' "/^git commit.*Set/s|v[0-9\.]*|v${NEW_BDCC_VERSION}|" "${PROJECT_DIR}/docs/config-files.md" || exit 6
}

while getopts "v:h" opt; do
  case "${opt}" in
    "v")
      # v = version (new)
      NEW_BDCC_VERSION="${OPTARG}"
      ;;
    "h" )
      # h = help
      usage 0 ;;
    * ) usage 1 ;;
  esac
done

if [ -z "${NEW_BDCC_VERSION}" ]; then
  usage 2
else
  RELEASE_BRANCH="release/${NEW_BDCC_VERSION}"
  message "${SCRIPT_NAME}" "INFO" "Creating branch [${RELEASE_BRANCH}]"
  git checkout -b "${RELEASE_BRANCH}" || exit 7

  message "${SCRIPT_NAME}" "INFO" "Updating to BDCC_VERSION [${NEW_BDCC_VERSION}] in [${FILES_TO_UPDATE[*]}] using sed"
  sedUpdates

  message "${SCRIPT_NAME}" "INFO" "Changes:"
  git diff || exit 8

  message "${SCRIPT_NAME}" "INFO" "Adding updated files to [${RELEASE_BRANCH}]"
  cd "${PROJECT_DIR}" && git add "${FILES_TO_UPDATE[@]}" || exit 9

  message "${SCRIPT_NAME}" "INFO" "Commiting updated files to [${RELEASE_BRANCH}]"
  git commit -m "Bump BDCC_VERSION to ${NEW_BDCC_VERSION}" || exit 10

  message "${SCRIPT_NAME}" "INFO" "Pushing branch [${RELEASE_BRANCH}]"
  git push || exit 11
fi
