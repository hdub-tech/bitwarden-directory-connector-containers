#!/bin/bash
# ============================================================== #
# Pre-commit hook should be symlinked to $PROJECT_DIR/.git/hooks!
#
# 1. Runs markdownlint-cli2 if *.md files were changed
# 2. Runs hadolint if Dockerfile files were changed
# 3. Runs shellcheck if *.sh files were changed
# ============================================================== #

echo "==> Executing pre-commit hook..."
PROJECT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../" && pwd )
FILES_CHANGED=$( git diff-index --cached --diff-filter=d --name-only HEAD )
PODMAN_OR_DOCKER=$( which podman || which docker || (echo "Please install podman or docker!" && exit 1) )
declare -a FAILED_TESTS

# =============================================== #
# Run markdownlint-cli2 if Markdown files changed #
# =============================================== #
MARKDOWNLINT_CLI2_REPO="docker.io/davidanson/markdownlint-cli2"
MARKDOWNLINT_CLI2_VERSION="v0.16.0"
MD_FILES_CHANGED=$( echo "$FILES_CHANGED" | awk '{if ($1 ~ /.*md.*/) {print "true"; exit}}' )
if [ "$MD_FILES_CHANGED" == "true" ]; then
  echo "==> Executing markdownlint-cli2 on changed **/*.md* files..."
  "$PODMAN_OR_DOCKER" run -v "$PROJECT_DIR":/workdir "$MARKDOWNLINT_CLI2_REPO":"$MARKDOWNLINT_CLI2_VERSION" && echo "==> markdownlint-cli2 completed successfully." || FAILED_TESTS+=("markdownlint-cli")
fi

# =================================== #
# Run hadolint on changed Dockerfiles #
# =================================== #
HADOLINT_REPO="docker.io/hadolint/hadolint"
HADOLINT_VERSION="v2.12.0"
DOCKER_FILES_CHANGED=$( echo "$FILES_CHANGED" | awk '{for( i=1; i<=NF; i++ ) {if ($i ~ /Dockerfile/) {print $i}}}' )
for dockerfile in $DOCKER_FILES_CHANGED; do
  echo "==> Executing hadolint on changed $dockerfile..."
  "$PODMAN_OR_DOCKER" run --rm -i "$HADOLINT_REPO":"$HADOLINT_VERSION" < "$dockerfile" && echo "==> hadolint completed successfully." || FAILED_TESTS+=("hadolint")
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
