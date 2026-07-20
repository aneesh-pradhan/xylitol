#!/usr/bin/env bash
# Unpack a Motorola XT1765 / perry CFC firmware package for extract-files.
#
# Motorola ships the package as a directory whose name ends in `.xml`. Inside:
# system.img_sparsechunk.* and oem.img (Android sparse). After simg2img the
# images still have a MOT_PIV_FULL256 wrapper; the ext4 filesystem starts at
# offset 131072 (128 KiB).
#
# Usage:
#   ./scripts/unpack-stock.sh /path/to/XT1765_…_CFC.xml [outdir]
#
# Default outdir: ~/android/stock-perry-NCQS26.69-64-21
#
# After unpack, extract with:
#   ./scripts/extract-perry.sh "$OUTDIR/tree"
set -euo pipefail

SRC="${1:-}"
OUTDIR="${2:-$HOME/android/stock-perry-NCQS26.69-64-21}"
HEADER_BYTES=131072

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "usage: $0 /path/to/XT1765_…_CFC.xml [outdir]" >&2
  echo "error: source must be an existing CFC directory" >&2
  exit 1
fi

if ! command -v simg2img >/dev/null 2>&1; then
  echo "error: simg2img not found (install android-sdk-libsparse-utils or" >&2
  echo "       build/host tools; on Ubuntu: apt install android-sdk-libsparse-utils)" >&2
  exit 1
fi

shopt -s nullglob
chunks=("$SRC"/system.img_sparsechunk.*)
shopt -u nullglob
if [ "${#chunks[@]}" -eq 0 ]; then
  echo "error: no system.img_sparsechunk.* under $SRC" >&2
  exit 1
fi
if [ ! -f "$SRC/oem.img" ]; then
  echo "error: missing $SRC/oem.img" >&2
  exit 1
fi

mkdir -p "$OUTDIR"
echo "==> Unpacking stock from $SRC -> $OUTDIR"

echo "==> simg2img system sparsechunks"
simg2img "${chunks[@]}" "$OUTDIR/system.raw.img"

echo "==> simg2img oem.img"
simg2img "$SRC/oem.img" "$OUTDIR/oem.raw.img"

echo "==> Strip MOT_PIV header (${HEADER_BYTES} bytes) -> ext4 images"
dd if="$OUTDIR/system.raw.img" of="$OUTDIR/system.img" bs="$HEADER_BYTES" skip=1 status=none
dd if="$OUTDIR/oem.raw.img" of="$OUTDIR/oem.img" bs="$HEADER_BYTES" skip=1 status=none

# Sanity: ext4 magic 0xEF53 at offset 0x438
check_ext4() {
  local img="$1"
  local magic
  magic="$(od -An -tx1 -N2 -j1080 "$img" | tr -d ' \n')"
  if [ "$magic" != "53ef" ]; then
    echo "warning: $img may not look like ext4 after strip (got $magic, want 53ef)" >&2
  fi
}
check_ext4 "$OUTDIR/system.img"
check_ext4 "$OUTDIR/oem.img"

mkdir -p "$OUTDIR/mnt-system" "$OUTDIR/mnt-oem" "$OUTDIR/tree"

cat > "$OUTDIR/README.txt" <<EOF
XT1765 / perry stock firmware unpack
Source: $SRC
Unpacked: $(date -Iseconds)
Images: system.img / oem.img (ext4, header stripped)
Mount points: mnt-system / mnt-oem
extract-files root: tree/ (symlinks to mounts)
EOF

mount_one() {
  local img="$1"
  local mnt="$2"
  if mountpoint -q "$mnt" 2>/dev/null; then
    echo "==> already mounted: $mnt"
    return 0
  fi
  if sudo mount -o ro,loop "$img" "$mnt"; then
    echo "==> mounted $img -> $mnt"
  else
    echo "warning: could not mount $img (run: sudo mount -o ro,loop $img $mnt)" >&2
    return 1
  fi
}

MOUNTED=0
if mount_one "$OUTDIR/system.img" "$OUTDIR/mnt-system"; then
  MOUNTED=1
fi
if mount_one "$OUTDIR/oem.img" "$OUTDIR/mnt-oem"; then
  MOUNTED=1
fi

ln -sfn ../mnt-system "$OUTDIR/tree/system"
ln -sfn ../mnt-oem "$OUTDIR/tree/oem"

echo "==> Done."
if [ "$MOUNTED" -eq 1 ]; then
  echo "    Extract with: ./scripts/extract-perry.sh $OUTDIR/tree"
else
  echo "    Mount the images, then: ./scripts/extract-perry.sh $OUTDIR/tree"
fi
