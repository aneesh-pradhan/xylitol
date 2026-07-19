#!/usr/bin/env bash
# Applies patches/ onto the synced tree at $LINEAGE_DIR, so it can be rebuilt
# from scratch after sync.sh: patches/<target-repo-path>/*.patch -> git am
# inside $LINEAGE_DIR/<target-repo-path>.
set -euo pipefail

LINEAGE_DIR="${LINEAGE_DIR:-$HOME/android/lineage}"
META_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHES_DIR="$META_DIR/patches"

if [ ! -d "$PATCHES_DIR" ]; then
  echo "No patches directory at $PATCHES_DIR" >&2
  exit 1
fi

find "$PATCHES_DIR" -mindepth 1 -type d | while read -r dir; do
  target_path="${dir#"$PATCHES_DIR"/}"
  target="$LINEAGE_DIR/$target_path"
  shopt -s nullglob
  patches=("$dir"/*.patch)
  shopt -u nullglob
  [ "${#patches[@]}" -eq 0 ] && continue

  if [ ! -d "$target/.git" ]; then
    echo "Skipping $target_path: not synced at $target" >&2
    continue
  fi

  echo "==> Applying ${#patches[@]} patch(es) to $target_path"
  git -C "$target" am "${patches[@]}"
done
