#!/usr/bin/env bash
# Init/sync official TWRP (Omni 7.1) for perry, wrap broken prebuilt flex,
# and apply xylitol patches/twrp/.
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

# Prebuilt flex-2.5.39 aborts on glibc 2.39+ locales; wrap to system flex.
FLEX="$TWRP_DIR/prebuilts/misc/linux-x86/flex/flex-2.5.39"
if [[ -e "$FLEX" ]] && ! grep -q 'exec /usr/bin/flex' "$FLEX" 2>/dev/null; then
  echo "==> wrapping prebuilt flex -> /usr/bin/flex"
  if [[ -f "$FLEX" && ! -f "${FLEX}.broken" ]]; then
    mv "$FLEX" "${FLEX}.broken"
  fi
  cat > "$FLEX" << 'EOF'
#!/bin/bash
export LC_ALL=C LANG=C
exec /usr/bin/flex "$@"
EOF
  chmod +x "$FLEX"
fi

echo "==> applying xylitol TWRP patches"
bash "$ROOT/scripts/apply-twrp-patches.sh"

echo "==> sync complete. Build with: bash $ROOT/scripts/build-twrp.sh"
