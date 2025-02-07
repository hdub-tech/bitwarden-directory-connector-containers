#!/bin/bash
# ============================================================== #
# Pre-commit hook should be symlinked to $PROJECT_DIR/.git/hooks!
#
# 1. Runs markdownlint-cli2 if *.md files were changed*
# 2. Runs hadolint if Containerfile files were changed*
# 3. Runs shellcheck if *.sh files were changed*
#
# * = Excludes deleted files
# ============================================================== #

echo -n "==> Executing pre-commit hook "

# TODO: Hack to run this script in GH Action until using corresponding actions
COMPARE_TREE=HEAD
PROJECT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
if [ -n "${GITHUB_ACTIONS}" ]; then
  COMPARE_TREE="origin/main"
  PROJECT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )
fi
echo "against files changed since ${COMPARE_TREE}..."

GIT_ERROR_LOG=/tmp/git.err
FILES_CHANGED=$( git diff-index --cached --diff-filter=d --name-only "${COMPARE_TREE}" 2>${GIT_ERROR_LOG} )
[ -s "${GIT_ERROR_LOG}" ] && cat ${GIT_ERROR_LOG} && exit 1

declare -a FAILED_TESTS
PODMAN_OR_DOCKER=$( which podman || which docker )
[ -z "${PODMAN_OR_DOCKER}" ] && echo "Please install podman or docker!" && exit 2

# =============================================== #
# Run markdownlint-cli2 if Markdown files changed #
# =============================================== #
MARKDOWNLINT_CLI2_REPO="docker.io/davidanson/markdownlint-cli2"
MARKDOWNLINT_CLI2_VERSION="v0.16.0"
MD_FILES_CHANGED=$( echo "$FILES_CHANGED" | awk '{if ($1 ~ /.*md.*/) {print "true"; exit}}' )
if [ "$MD_FILES_CHANGED" == "true" ]; then
  echo "==> Executing markdownlint-cli2 on all **/*.md* files..."
  "$PODMAN_OR_DOCKER" run --rm -v "$PROJECT_DIR":/workdir "$MARKDOWNLINT_CLI2_REPO":"$MARKDOWNLINT_CLI2_VERSION" && echo "==> markdownlint-cli2 completed successfully." || FAILED_TESTS+=("markdownlint-cli")
fi

# ====================================== #
# Run hadolint on changed Containerfiles #
# ====================================== #
HADOLINT_REPO="docker.io/hadolint/hadolint"
HADOLINT_VERSION="v2.12.0"
CONTAINER_FILES_CHANGED=$( echo "$FILES_CHANGED" | awk '{for( i=1; i<=NF; i++ ) {if ($i ~ /Containerfile/) {print $i}}}' )
for containerfile in $CONTAINER_FILES_CHANGED; do
  echo "==> Executing hadolint on changed $containerfile..."
  "$PODMAN_OR_DOCKER" run --rm -i "$HADOLINT_REPO":"$HADOLINT_VERSION" < "$containerfile" && echo "==> hadolint completed successfully." || FAILED_TESTS+=("hadolint")
done

# ============================== #
# Execute shellcheck on sh files #
# ============================== #
SHELL_FILES_CHANGED=$( echo "$FILES_CHANGED" | awk 'BEGIN { ORS = " " } { for(i = 1 ; i <= NF ; i++) { if($i ~ /.*\.sh/) { print $i } } }' )
if [ -n "$SHELL_FILES_CHANGED" ]; then
  echo "==> Executing shellcheck on changed **/*.sh files..."
  # shellcheck disable=SC2086
  shellcheck ${SHELL_FILES_CHANGED} && echo "==> shellcheck completed successfully." || FAILED_TESTS+=("shellcheck")
fi

# ===================================== #
# Report errors and fail as appropriate #
# ===================================== #
if (( "${#FAILED_TESTS}" > 0 )); then
  echo "==> Pre-commit tests failed! See previous output for: ${FAILED_TESTS[*]}"
  exit 1
else
  echo "==> Pre-commit tests passed!"
fi
