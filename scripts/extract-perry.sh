#!/usr/bin/env bash
# Safe perry blob extract: never wipe msm8937-common proprietary.
#
# msm8937-common's extract-files.sh defaults to CLEAN_VENDOR=true, which
# deletes vendor/motorola/msm8937-common/proprietary/ before extracting.
# Always pass -n (--no-cleanup) and --only-target for perry-only refreshes.
#
# Usage:
#   ./scripts/extract-perry.sh [adb|path-to-dump]
# Defaults to adb if no argument is given.
set -euo pipefail

LINEAGE_DIR="${LINEAGE_DIR:-$HOME/android/lineage}"
DEVICE_DIR="$LINEAGE_DIR/device/motorola/perry"
SRC="${1:-adb}"

if [ ! -x "$DEVICE_DIR/extract-files.sh" ]; then
  echo "error: missing $DEVICE_DIR/extract-files.sh (sync the Lineage tree first)" >&2
  exit 1
fi

echo "==> perry-only extract (CLEAN_VENDOR=false, --only-target), source=$SRC"
cd "$DEVICE_DIR"
exec ./extract-files.sh -n --only-target "$SRC"
