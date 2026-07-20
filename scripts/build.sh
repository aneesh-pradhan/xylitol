#!/usr/bin/env bash
# Build LineageOS 18.1 for perry (lineage_perry-userdebug).
#
# Prerequisites: sync.sh, apply-patches.sh, and extract-perry.sh (or existing
# vendor blobs under ~/android/lineage/vendor/motorola).
#
# Usage:
#   ./scripts/build.sh              # m bacon
#   ./scripts/build.sh vendorimage  # m vendorimage only
#   EXTRA_ARGS="-j8" ./scripts/build.sh
set -euo pipefail

LINEAGE_DIR="${LINEAGE_DIR:-$HOME/android/lineage}"
TARGET="${1:-bacon}"
JOBS="${JOBS:-$(nproc)}"

if [ ! -f "$LINEAGE_DIR/build/envsetup.sh" ]; then
  echo "error: no Lineage tree at $LINEAGE_DIR (run scripts/sync.sh first)" >&2
  exit 1
fi

if [ -z "${MKE2FS_CONFIG:-}" ]; then
  if [ -f "$HOME/android/mke2fs.conf" ]; then
    export MKE2FS_CONFIG="$HOME/android/mke2fs.conf"
  else
    echo "warning: MKE2FS_CONFIG unset and $HOME/android/mke2fs.conf missing;" >&2
    echo "         run scripts/setup-env.sh (Ubuntu 24.04+ apexer needs it)." >&2
  fi
fi

# insertkeys.py in 18.1 still expects Python 2.7 for some host paths
PY27="$LINEAGE_DIR/prebuilts/python/linux-x86/2.7.5/bin"
if [ -d "$PY27" ]; then
  export PATH="$PY27:$PATH"
fi

cd "$LINEAGE_DIR"
# shellcheck disable=SC1091
source build/envsetup.sh
lunch lineage_perry-userdebug

echo "==> m $TARGET -j$JOBS"
# shellcheck disable=SC2086
m "$TARGET" -j"$JOBS" ${EXTRA_ARGS:-}

echo "==> Done. Artifacts under $LINEAGE_DIR/out/target/product/perry/"
