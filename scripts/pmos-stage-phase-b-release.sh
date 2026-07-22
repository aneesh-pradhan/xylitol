#!/usr/bin/env bash
# Stage a durable Phase B (first-class linux-motorola-perry) RC from an
# already-built phase-b image. Does NOT rebuild. Does NOT flash. Does NOT
# overwrite artifacts/pmos-release/pmos-perry-2026-07-21/ (rollback).
#
# Usage:
#   ./scripts/pmos-stage-phase-b-release.sh
#   RELEASE_TAG=pmos-perry-2026-07-22 ./scripts/pmos-stage-phase-b-release.sh
#
# Env:
#   RELEASE_TAG   default: pmos-perry-YYYY-MM-DD (UTC)
#   SRC_DIR       default: artifacts/pmos-phase-b
#   RAW_NAME      default: motorola-perry-phosh.img
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$XYLITOL_ROOT"

DATE_UTC="$(date -u +%Y-%m-%d)"
RELEASE_TAG="${RELEASE_TAG:-pmos-perry-${DATE_UTC}}"
SRC_DIR="${SRC_DIR:-$XYLITOL_ROOT/artifacts/pmos-phase-b}"
OUT_DIR="$XYLITOL_ROOT/artifacts/pmos-release/${RELEASE_TAG}"
RAW_NAME="${RAW_NAME:-motorola-perry-phosh.img}"
SPARSE_NAME="${RAW_NAME%.img}.sparse.img"
LK2ND_NAME="lk2nd-msm8952-perry.img"
ROLLBACK_TAG="pmos-perry-2026-07-21"
MARKER='Fastboot mode was forced with compile-time flag.'

if [[ "$RELEASE_TAG" == "$ROLLBACK_TAG" ]]; then
  echo "ERROR: refusing to overwrite rollback tag $ROLLBACK_TAG" >&2
  exit 1
fi

command -v zstd >/dev/null || { echo "ERROR: zstd required" >&2; exit 1; }

RAW="$SRC_DIR/$RAW_NAME"
SPARSE="$SRC_DIR/$SPARSE_NAME"
LK2ND="$SRC_DIR/$LK2ND_NAME"

[[ -f "$RAW" && -f "$SPARSE" && -f "$LK2ND" ]] || {
  echo "ERROR: need $RAW, $SPARSE, $LK2ND" >&2
  exit 1
}

if grep -aFq "$MARKER" "$LK2ND"; then
  echo "ERROR: $LK2ND is FORCE-FASTBOOT — refusing to ship as NORMAL" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
echo "==> Staging $RELEASE_TAG from $SRC_DIR → $OUT_DIR"
cp --reflink=auto -v "$LK2ND" "$OUT_DIR/$LK2ND_NAME"
cp --reflink=auto -v "$RAW" "$OUT_DIR/$RAW_NAME"
cp --reflink=auto -v "$SPARSE" "$OUT_DIR/$SPARSE_NAME"

if [[ ! "$OUT_DIR/$SPARSE_NAME" -nt "$OUT_DIR/$RAW_NAME" ]]; then
  touch "$OUT_DIR/$SPARSE_NAME"
fi

echo "==> zstd -19"
zstd -f -T0 -19 "$OUT_DIR/$RAW_NAME" -o "$OUT_DIR/${RAW_NAME}.zst"

LK2ND_BYTES="$(stat -c%s "$OUT_DIR/$LK2ND_NAME")"
ROOTFS_BYTES="$(stat -c%s "$OUT_DIR/$RAW_NAME")"
SPARSE_BYTES="$(stat -c%s "$OUT_DIR/$SPARSE_NAME")"
ZST_BYTES="$(stat -c%s "$OUT_DIR/${RAW_NAME}.zst")"

# Best-effort package versions from the raw image (ro,noload).
KERNEL_VER="(loop-mount to confirm)"
DEVICE_VER="(loop-mount to confirm)"
INITFS_VER="(loop-mount to confirm)"
FLAVOR="(loop-mount to confirm)"
LOOP=""
cleanup_loop() {
  sudo umount /mnt/pmos-stage-boot 2>/dev/null || true
  sudo umount /mnt/pmos-stage-root 2>/dev/null || true
  [[ -n "$LOOP" ]] && sudo losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup_loop EXIT
sudo mkdir -p /mnt/pmos-stage-boot /mnt/pmos-stage-root
LOOP="$(sudo losetup -fP --show "$OUT_DIR/$RAW_NAME")"
sudo mount -o ro "${LOOP}p1" /mnt/pmos-stage-boot
sudo mount -o ro,noload "${LOOP}p2" /mnt/pmos-stage-root || \
  sudo mount -o ro "${LOOP}p2" /mnt/pmos-stage-root

sudo grep -q 'fdt /msm8917-motorola-perry.dtb' /mnt/pmos-stage-boot/extlinux/extlinux.conf \
  || { echo "ERROR: extlinux missing perry fdt" >&2; exit 1; }
if sudo grep -q 'deviceinfo_framebuffer_wait_seconds' \
     /mnt/pmos-stage-root/usr/share/initramfs/init_functions.sh 2>/dev/null; then
  echo "ERROR: P1.5 present in initramfs — refusing to stage" >&2
  exit 1
fi
FLAVOR="$(sudo ls /mnt/pmos-stage-root/usr/lib/modules/ 2>/dev/null | head -1 || true)"
if sudo test -f /mnt/pmos-stage-root/lib/apk/db/installed; then
  KERNEL_VER="$(sudo awk '/^P:linux-motorola-perry$/{p=1} p&&/^V:/{print substr($0,3); exit}' \
    /mnt/pmos-stage-root/lib/apk/db/installed)"
  DEVICE_VER="$(sudo awk '/^P:device-motorola-perry$/{p=1} p&&/^V:/{print substr($0,3); exit}' \
    /mnt/pmos-stage-root/lib/apk/db/installed)"
  INITFS_VER="$(sudo awk '/^P:postmarketos-initramfs$/{p=1} p&&/^V:/{print substr($0,3); exit}' \
    /mnt/pmos-stage-root/lib/apk/db/installed)"
fi
APPS_NOTE="lean (\`--no-recommends\`)"
if sudo test -f /mnt/pmos-stage-root/usr/share/applications/org.gnome.Calculator.desktop \
  && sudo test -f /mnt/pmos-stage-root/usr/share/applications/firefox-esr.desktop; then
  APPS_NOTE="**full Phosh recommends** (Calculator, Calendar, Console, Firefox-ESR, Chatty, Calls, …)"
fi
cleanup_loop
trap - EXIT

cat > "$OUT_DIR/FLASH.md" <<EOF
# postmarketOS (Phosh) for Moto E4 perry — ${RELEASE_TAG}

Flashable **RC** for **XT1765 / perry** (MSM8917). First-class Phase B
(\`linux-motorola-perry\` / \`device-motorola-perry\`) — not the generic
\`qcom-msm89x7\` overlay path used by \`${ROLLBACK_TAG}\`.

| Item | Value |
|---|---|
| Kernel | \`${FLAVOR}\` / \`linux-motorola-perry\` **${KERNEL_VER}** |
| Device pkg | \`device-motorola-perry\` **${DEVICE_VER}** |
| Initramfs | \`postmarketos-initramfs\` **${INITFS_VER}** (unpatched) |
| P1.5 framebuffer-wait | **OFF** (known hang — do not re-enable) |
| UI / apps | Phosh — ${APPS_NOTE} |

**Rollback:** \`../${ROLLBACK_TAG}/\` via \`./scripts/pmos-rollback-known-good.sh\`.

## Assets

| File | What |
|---|---|
| \`${LK2ND_NAME}\` | **NORMAL** lk2nd → flash to \`boot\` |
| \`${RAW_NAME}.zst\` | Combined boot+root (compressed) |
| \`${SPARSE_NAME}\` | Sparse userdata for chunked flash |
| \`${RAW_NAME}\` | Raw combined image |
| \`SHA256SUMS\` | Checksums |

Default user: **xylitol** / password: **xylitol**.
SSH USB-net: \`xylitol@172.16.42.1\` (host \`172.16.42.2/24\` on \`enx*\`).

## Flash (preferred)

Sacred — never wipe/flash \`persist\`, \`modemst1\`, \`modemst2\`.

\`\`\`bash
OUT=\$PWD/artifacts/pmos-release/${RELEASE_TAG} \\
RAW=\$OUT/${RAW_NAME} \\
SPARSE=\$OUT/${SPARSE_NAME} \\
NORMAL=\$OUT/${LK2ND_NAME} \\
FORCE=\$PWD/artifacts/pmos-phase-b/lk2nd-force-fastboot.img \\
  ./scripts/pmos-flash-phase-b-force.sh
\`\`\`

## Sizes (this build)

- lk2nd: ${LK2ND_BYTES} bytes
- rootfs (raw): ${ROOTFS_BYTES} bytes
- rootfs (sparse): ${SPARSE_BYTES} bytes
- rootfs (.zst): ${ZST_BYTES} bytes

Staged by \`scripts/pmos-stage-phase-b-release.sh\` from \`${SRC_DIR}\`.
EOF

(
  cd "$OUT_DIR"
  sha256sum \
    "$LK2ND_NAME" \
    "${RAW_NAME}.zst" \
    "$RAW_NAME" \
    "$SPARSE_NAME" \
    > SHA256SUMS
)

echo
echo "OK. Staged $OUT_DIR"
ls -lh "$OUT_DIR"
echo "Kernel flavor: $FLAVOR  pkgs: linux=$KERNEL_VER device=$DEVICE_VER initramfs=$INITFS_VER"
echo "Rollback untouched: artifacts/pmos-release/${ROLLBACK_TAG}/"
