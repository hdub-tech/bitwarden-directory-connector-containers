#!/bin/bash

set -x

BW_KEYFILE=/run/secrets/bw_key

echo "bwdc version: $( bwdc --version )"
echo "bwdc data-file: $( bwdc data-file )"

if bwdc login; then
  echo logged in

  # Config set-up
  bwdc config server "$BW_SERVER"
  bwdc config directory "$BW_DIRECTORY"
  # The key has to be a file on disk :(
  bwdc config "$BW_KEYTYPE.key" "$BW_KEYFILE"
  bwdc test
  #bwdc logout
else
  echo NOT logged in
fi
