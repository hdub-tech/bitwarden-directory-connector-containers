#!/bin/bash

# $1 = script, $2 = level, $@ = message
message() {
  script=$1
  shift
  level=$1
  shift
  echo "[${script}] ${level}: $*"
}

buildPodmanRunSecretsOptions() {
  declare -a SECRETS_OPTS
  case "${SECRETS_MANAGER}" in
    "env" )
      SECRETS_OPTS+=("--env-file ${SCRIPT_DIR}/${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}/env.vars")
      ;;
    "podman" )
      SECRETS_OPTS+=("--secret=bw_clientid,type=env,target=BW_CLIENTID")
      SECRETS_OPTS+=("--secret=bw_clientsecret,type=env,target=BW_CLIENTSECRET")
      [[ "gsuite" == "${BITWARDENCLI_CONNECTOR_DIRECTORY_TYPE}" ]] && SECRETS_OPTS+=("--secret=bw_gsuitekey,type=env,target=BW_GSUITEKEY")
      ;;
  esac
  echo "${SECRETS_OPTS[*]}"
}
