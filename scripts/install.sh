#!/bin/bash

set -euo pipefail

REPOSITORY="svlucero/disksweep"
ARCHIVE_NAME="DiskSweep.zip"
INSTALL_DIR="${1:-$HOME/Applications}"
APP_NAME="DiskSweep.app"
DOWNLOAD_URL="https://github.com/${REPOSITORY}/releases/latest/download/${ARCHIVE_NAME}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "DiskSweep can only be installed on macOS." >&2
    exit 1
fi

if [[ "$#" -gt 1 ]]; then
    echo "Usage: install.sh [install-directory]" >&2
    exit 2
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v ditto >/dev/null 2>&1; then
    echo "This installer requires the macOS curl and ditto commands." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading the latest DiskSweep release..."
curl --fail --location --silent --show-error "$DOWNLOAD_URL" \
    --output "$WORK_DIR/$ARCHIVE_NAME"

ditto -x -k "$WORK_DIR/$ARCHIVE_NAME" "$WORK_DIR"

SOURCE_APP="$WORK_DIR/$APP_NAME"
if [[ ! -d "$SOURCE_APP" ]]; then
    echo "The release archive does not contain $APP_NAME." >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"
ditto "$SOURCE_APP" "$INSTALL_DIR/$APP_NAME"

# The published app is ad-hoc signed and is not notarized. Remove the download
# quarantine so macOS will allow it to open; the user must trust the release.
if command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true
fi

echo "DiskSweep was installed to: $INSTALL_DIR/$APP_NAME"
echo "Open it from Finder or run: open \"$INSTALL_DIR/$APP_NAME\""
