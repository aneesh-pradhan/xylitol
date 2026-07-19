#!/usr/bin/env bash
# Initializes the lineage-18.1 tree at $LINEAGE_DIR (default ~/android/lineage)
# and syncs it: shallow for the AOSP/LineageOS tree, full history for the
# perry device/kernel/vendor repos we'll be hacking on (see manifests/perry.xml).
set -euo pipefail

BRANCH="lineage-18.1"
LINEAGE_DIR="${LINEAGE_DIR:-$HOME/android/lineage}"
META_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_MANIFEST="$META_DIR/manifests/perry.xml"

if [ ! -f "$LOCAL_MANIFEST" ]; then
  echo "Missing $LOCAL_MANIFEST" >&2
  exit 1
fi

mkdir -p "$LINEAGE_DIR"
cd "$LINEAGE_DIR"

if [ ! -d .repo ]; then
  echo "==> repo init ($BRANCH, shallow)"
  repo init -u https://github.com/LineageOS/android.git -b "$BRANCH" \
    --git-lfs --depth=1 --no-clone-bundle
else
  echo "==> $LINEAGE_DIR already initialized, skipping repo init"
fi

echo "==> Installing local manifest"
mkdir -p .repo/local_manifests
cp "$LOCAL_MANIFEST" .repo/local_manifests/perry.xml

echo "==> repo sync"
repo sync -c --no-clone-bundle --no-tags

# repo init --depth=1 shallow-clones every project. Older repo accepted
# clone-depth="0" in the local manifest to opt out; current repo rejects
# that, so unshallow the perry-related projects here instead.
echo "==> Unshallowing perry device/kernel/vendor projects"
for path in \
  device/motorola/perry \
  device/motorola/msm8937-common \
  kernel/motorola/msm8953 \
  vendor/motorola
do
  target="$LINEAGE_DIR/$path"
  if [ ! -e "$target/.git" ]; then
    echo "  skip $path (not present)" >&2
    continue
  fi
  if [ "$(git -C "$target" rev-parse --is-shallow-repository 2>/dev/null || true)" = "true" ]; then
    echo "  unshallow $path"
    git -C "$target" fetch --unshallow
  else
    echo "  already full $path"
  fi
done

echo "==> Done. Source tree is at $LINEAGE_DIR."
