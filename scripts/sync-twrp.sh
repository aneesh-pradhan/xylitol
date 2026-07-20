#!/usr/bin/env bash
# Init/sync the official TWRP (Omni 7.1) tree for perry.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TWRP_DIR="${TWRP_DIR:-$HOME/android/twrp}"
MANIFEST_SRC="$ROOT/manifests/twrp-perry.xml"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "$TWRP_DIR"
cd "$TWRP_DIR"

if [[ ! -d .repo ]]; then
  echo "==> repo init (twrp-7.1, depth=1) in $TWRP_DIR"
  repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git \
    -b twrp-7.1 --depth=1
fi

mkdir -p .repo/local_manifests
cp -f "$MANIFEST_SRC" .repo/local_manifests/perry.xml
echo "==> installed local manifest: .repo/local_manifests/perry.xml"

echo "==> repo sync -c -j$JOBS"
repo sync -c --no-clone-bundle --no-tags -j"$JOBS"

echo "==> done. Host deps for build on Ubuntu 26.04:"
echo "  - OpenJDK 8: sudo apt install openjdk-8-jdk-headless"
echo "  - Python 2.7: micromamba create -y -n py27 -c conda-forge python=2.7"
echo "  - flex wrapper (prebuilt flex aborts on glibc 2.43+):"
echo "      mv prebuilts/misc/linux-x86/flex/flex-2.5.39{,.broken}"
echo "      printf '%s\\n' '#!/bin/bash' 'export LC_ALL=C LANG=C' 'exec /usr/bin/flex \"\$@\"' \\"
echo "        > prebuilts/misc/linux-x86/flex/flex-2.5.39 && chmod +x prebuilts/misc/linux-x86/flex/flex-2.5.39"
echo "  Then: bash $ROOT/scripts/build-twrp.sh"
