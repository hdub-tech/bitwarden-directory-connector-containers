#!/bin/bash

set -x

# data.json will be created with first bwdc command
echo "bwdc version: $( bwdc --version 2>/dev/null )"
BITWARDENCLI_CONNECTOR_DATAFILE="$( bwdc data-file 2>/dev/null )"


isLoggedOut() {
  # activeUserId does not exist initially and is set to null on logout
  [ ! -e "$BITWARDENCLI_CONNECTOR_DATAFILE" ] || jq -r '.activeUserId == null' "$BITWARDENCLI_CONNECTOR_DATAFILE"
}

login() {
  if isLoggedOut; then
    bwdc login
  fi
}

config() {
  # Config set-up
  
  # bwdc config doesn't work with plain text mode
  bwdc config server "$BW_SERVER"
  bwdc config directory "$BW_DIRECTORY"
  # The key has to be a file on disk :(
  bwdc config "$BW_KEYTYPE.key" "$BW_KEYFILE"
}
