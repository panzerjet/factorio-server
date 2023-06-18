#!/bin/bash
set -eou pipefail

# Update installation files
ARCHIVE="/tmp/factorio_headless_x64_$1.tar.xz"
curl -sSL "https://www.factorio.com/get-download/$1/headless/linux64" -o "$ARCHIVE" --retry 8

# Remove old files except 
find "$FACTORIO_APP" -mindepth 1 -type d \
! -path "${FACTORIO_APP}/scenarios" \
! -path "${FACTORIO_APP}/saves" \
! -path "${FACTORIO_APP}/config" \
-exec rm -r {} \;

# Inflate binaries
tar -xf "$ARCHIVE" --directory "$FACTORIO_APP/.."
rm "$ARCHIVE"
