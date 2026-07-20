#!/usr/bin/env bash
# Apply patches/twrp/<repo-path>/*.patch onto $TWRP_DIR/<repo-path> via git am.
# Idempotent-ish: skips if the tip commit message already matches the patch subject.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TWRP_DIR="${TWRP_DIR:-$HOME/android/twrp}"
PATCHES_ROOT="$ROOT/patches/twrp"

if [[ ! -d "$PATCHES_ROOT" ]]; then
  echo "No TWRP patches at $PATCHES_ROOT" >&2
  exit 0
fi

find "$PATCHES_ROOT" -mindepth 1 -type d | while read -r dir; do
  rel="${dir#"$PATCHES_ROOT"/}"
  target="$TWRP_DIR/$rel"
  shopt -s nullglob
  patches=("$dir"/*.patch)
  shopt -u nullglob
  [[ ${#patches[@]} -eq 0 ]] && continue

  if [[ ! -d "$target/.git" && ! -d "$TWRP_DIR/.repo/projects/${rel}.git" ]]; then
    # repo checkouts often have .git as a file pointing at .repo/projects
    if [[ ! -e "$target/.git" ]]; then
      echo "Skipping $rel: not synced at $target" >&2
      continue
    fi
  fi

  echo "==> Applying ${#patches[@]} patch(es) to $rel"
  for p in "${patches[@]}"; do
    subject=$(grep -m1 '^Subject:' "$p" | sed 's/^Subject:[[:space:]]*//; s/^\[PATCH[^]]*\][[:space:]]*//' || true)
    if [[ -n "$subject" ]] && git -C "$target" log -1 --pretty=%s 2>/dev/null | grep -Fxq "$subject"; then
      echo "    already applied: $(basename "$p")"
      continue
    fi
    if git -C "$target" am --3way "$p"; then
      echo "    applied: $(basename "$p")"
    else
      # If patch already in tree (dirty BoardConfig), try reverse-check
      if git -C "$target" apply --check -R "$p" 2>/dev/null; then
        echo "    already in working tree: $(basename "$p")"
        git -C "$target" am --abort 2>/dev/null || true
      else
        echo "ERROR: failed to apply $p" >&2
        git -C "$target" am --abort 2>/dev/null || true
        exit 1
      fi
    fi
  done
done
