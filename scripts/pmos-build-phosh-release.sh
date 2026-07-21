#!/usr/bin/env bash
# Build a durable, flashable postmarketOS (Phosh) image for Moto E4 perry and
# stage GitHub Release assets under artifacts/pmos-release/.
#
# Bakes in:
#   - UI: phosh (postmarketos-ui-phosh)
#   - deviceinfo-motorola-perry  (extlinux fdt pin + systemd linger)
#   - firmware-motorola-perry-nv (WCNSS Wi-Fi NV at the mainline DTS path)
#   - alsa-ucm-motorola-perry    (Speaker + Mic UCM + WirePlumber libcamera fix)
#   - lk2nd perry device-node carry (r3 backport)
#   - linux-postmarketos-qcom-msm89x7 perry/Ofilm overlay (already applied)
#
# Does NOT flash the device. Does NOT touch persist/modemst*.
#
# Usage:
#   ./scripts/pmos-build-phosh-release.sh           # build + stage assets
#   ./scripts/pmos-build-phosh-release.sh --upload  # also gh release create/upload
#
# Env overrides:
#   PMOS_PASSWORD   default image password (PLAIN TEXT; default: 147147)
#   PMOS_EXTRA_SPACE  free space on rootfs in MiB (default: 2048)
#   RELEASE_TAG     GitHub release tag (default: pmos-perry-YYYY-MM-DD)
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$XYLITOL_ROOT"

UPLOAD=0
for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

PMOS_PASSWORD="${PMOS_PASSWORD:-147147}"
PMOS_EXTRA_SPACE="${PMOS_EXTRA_SPACE:-2048}"
DATE_UTC="$(date -u +%Y-%m-%d)"
RELEASE_TAG="${RELEASE_TAG:-pmos-perry-${DATE_UTC}}"
OUT_DIR="$XYLITOL_ROOT/artifacts/pmos-release/${RELEASE_TAG}"
ADD_PKGS="deviceinfo-motorola-perry,firmware-motorola-perry-nv,alsa-ucm-motorola-perry"

export PATH="${HOME}/bin:${PATH}"
command -v pmbootstrap >/dev/null || {
  echo "ERROR: pmbootstrap not on PATH" >&2
  exit 1
}
command -v zstd >/dev/null || {
  echo "ERROR: zstd required to compress the rootfs for GitHub Releases" >&2
  exit 1
}

echo "==> Applying xylitol pmos overlays into live pmaports"
./scripts/pmos-apply-perry-kernel.sh
./scripts/pmos-apply-perry-firmware.sh
./scripts/pmos-apply-perry-deviceinfo.sh
./scripts/pmos-apply-perry-ucm.sh
./scripts/pmos-apply-lk2nd-perry.sh

echo "==> pmbootstrap config: ui=phosh, extra_space=${PMOS_EXTRA_SPACE}"
pmbootstrap config ui phosh
pmbootstrap config extra_space "$PMOS_EXTRA_SPACE"
# Keep hostname/user; ensure SSH + keys for maintainer access after flash.
pmbootstrap config ssh_keys True
pmbootstrap config hostname perry

echo "==> Building local packages"
pmbootstrap build deviceinfo-motorola-perry
pmbootstrap build firmware-motorola-perry-nv
pmbootstrap build alsa-ucm-motorola-perry
pmbootstrap build lk2nd
# Kernel overlay is already at 7.0.9-r2 with Ofilm; rebuild only if needed.
pmbootstrap build linux-postmarketos-qcom-msm89x7

echo "==> pmbootstrap install (Phosh + perry extras) — this takes a while"
# --zap: clean chroots so console→phosh switch is complete.
# Password is intentionally a known dummy for the public flashable image.
pmbootstrap install --zap --password "$PMOS_PASSWORD" --add "$ADD_PKGS"

echo "==> Exporting images"
pmbootstrap export
EXPORT_DIR="/tmp/postmarketOS-export"
ROOTFS_SRC=""
LK2ND_SRC=""
for cand in \
  "$EXPORT_DIR/qcom-msm89x7.img" \
  "$HOME/pmos/work/chroot_native/home/pmos/rootfs/qcom-msm89x7.img"
do
  if [[ -f "$cand" ]]; then
    ROOTFS_SRC="$cand"
    break
  fi
done
for cand in \
  "$EXPORT_DIR/lk2nd-msm8952.img" \
  "$EXPORT_DIR/lk2nd.img" \
  "$HOME/pmos/work/chroot_rootfs_qcom-msm89x7/boot/lk2nd.img"
do
  if [[ -f "$cand" ]]; then
    LK2ND_SRC="$cand"
    break
  fi
done
[[ -n "$ROOTFS_SRC" ]] || { echo "ERROR: rootfs image not found after export" >&2; exit 1; }
[[ -n "$LK2ND_SRC" ]] || { echo "ERROR: lk2nd image not found after export" >&2; exit 1; }

mkdir -p "$OUT_DIR"
ROOTFS_NAME="qcom-msm89x7-perry-phosh.img"
LK2ND_NAME="lk2nd-msm8952-perry.img"
cp -v "$ROOTFS_SRC" "$OUT_DIR/$ROOTFS_NAME"
cp -v "$LK2ND_SRC" "$OUT_DIR/$LK2ND_NAME"

echo "==> Compressing rootfs with zstd (GitHub Release size)"
zstd -f -T0 -19 "$OUT_DIR/$ROOTFS_NAME" -o "$OUT_DIR/${ROOTFS_NAME}.zst"
# Keep the uncompressed copy locally for flashing; release uploads the .zst.
ROOTFS_BYTES="$(stat -c%s "$OUT_DIR/$ROOTFS_NAME")"
LK2ND_BYTES="$(stat -c%s "$OUT_DIR/$LK2ND_NAME")"
ZST_BYTES="$(stat -c%s "$OUT_DIR/${ROOTFS_NAME}.zst")"

(
  cd "$OUT_DIR"
  sha256sum "$LK2ND_NAME" "${ROOTFS_NAME}.zst" "$ROOTFS_NAME" > SHA256SUMS
)

# Sanity: durable bits inside the image
echo "==> Sanity-checking image contents (loop-mount pmOS_boot + root)"
LOOP="$(sudo losetup -fP --show "$OUT_DIR/$ROOTFS_NAME")"
cleanup_loop() {
  sudo umount /mnt/pmos-rel-boot 2>/dev/null || true
  sudo umount /mnt/pmos-rel-root 2>/dev/null || true
  sudo losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup_loop EXIT
sudo mkdir -p /mnt/pmos-rel-boot /mnt/pmos-rel-root
sudo mount "${LOOP}p1" /mnt/pmos-rel-boot
sudo mount "${LOOP}p2" /mnt/pmos-rel-root

EXTLINUX="$(sudo cat /mnt/pmos-rel-boot/extlinux/extlinux.conf)"
echo "$EXTLINUX" | grep -q 'fdt /msm8917-motorola-perry.dtb' \
  || { echo "ERROR: extlinux missing explicit perry fdt" >&2; echo "$EXTLINUX"; exit 1; }
sudo test -f /mnt/pmos-rel-boot/msm8917-motorola-perry.dtb \
  || { echo "ERROR: perry DTB missing from boot" >&2; exit 1; }
sudo test -f /mnt/pmos-rel-root/etc/deviceinfo \
  || { echo "ERROR: /etc/deviceinfo missing" >&2; exit 1; }
sudo test -f /mnt/pmos-rel-root/var/lib/systemd/linger/aneesh \
  || { echo "ERROR: linger marker missing" >&2; exit 1; }
sudo test -f /mnt/pmos-rel-root/lib/firmware/qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin \
  || { echo "ERROR: WCNSS NV missing at DTS path" >&2; exit 1; }
sudo test -f /mnt/pmos-rel-root/usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf \
  || { echo "ERROR: perry UCM missing" >&2; exit 1; }
sudo test -d /mnt/pmos-rel-root/usr/share/phosh -o -e /mnt/pmos-rel-root/usr/bin/phosh \
  || sudo test -e /mnt/pmos-rel-root/usr/bin/phoc \
  || { echo "ERROR: Phosh/phoc not found in rootfs" >&2; exit 1; }

cleanup_loop
trap - EXIT

cat > "$OUT_DIR/FLASH.md" <<EOF
# postmarketOS (Phosh) for Moto E4 perry — ${RELEASE_TAG}

Flashable images for **XT1765 / perry** (MSM8917). Built from
[xylitol](https://github.com/aneesh-pradhan/xylitol) overlays on postmarketOS
edge + \`linux-postmarketos-qcom-msm89x7\` with the perry/Ofilm carry.

## Assets

| File | What |
|---|---|
| \`${LK2ND_NAME}\` | lk2nd (perry device node) → flash to \`boot\` |
| \`${ROOTFS_NAME}.zst\` | Combined boot+root image → decompress, flash to \`userdata\` |
| \`SHA256SUMS\` | Checksums |

Default user: **aneesh** / password: **${PMOS_PASSWORD}** (change after first boot).
SSH over USB-net: \`aneesh@172.16.42.1\` (host self-assigns \`172.16.42.2/24\`).

## Flash (destructive to userdata)

Sacred — never wipe/flash \`persist\`, \`modemst1\`, \`modemst2\`.

\`\`\`bash
# 1. Decompress rootfs
zstd -d ${ROOTFS_NAME}.zst

# 2. From STOCK fastboot (adb reboot bootloader):
fastboot flash boot ${LK2ND_NAME}
# "Image not signed or corrupt" is normal on unlocked Motos.

# 3. Reboot into lk2nd fastboot: fastboot reboot, hold Volume-Down
fastboot getvar product   # expect: lk2nd-msm8952

# 4. Flash rootfs (~2–3 min)
fastboot flash userdata ${ROOTFS_NAME}

# 5. Boot
fastboot continue
\`\`\`

On first boot expect Phosh (phrog greeter → phosh session), Wi-Fi, and
speaker audio. USB-net gadget is CDC-NCM at \`172.16.42.1\`.

## What's baked in

- Phosh mobile UI (\`postmarketos-ui-phosh\`)
- \`deviceinfo-motorola-perry\` — \`fdt /msm8917-motorola-perry.dtb\` + linger
- \`firmware-motorola-perry-nv\` — WCNSS NV for \`wcn36xx\`
- \`alsa-ucm-motorola-perry\` — Speaker + Mic UCM
- lk2nd perry node + Ofilm 499v0 panel kernel carry

## Sizes (this build)

- lk2nd: ${LK2ND_BYTES} bytes
- rootfs (raw): ${ROOTFS_BYTES} bytes
- rootfs (.zst): ${ZST_BYTES} bytes
EOF

echo
echo "OK. Staged release assets in:"
echo "  $OUT_DIR"
ls -lh "$OUT_DIR"
echo
echo "FLASH.md password for this image: $PMOS_PASSWORD"

if [[ "$UPLOAD" -eq 1 ]]; then
  command -v gh >/dev/null || { echo "ERROR: gh CLI required for --upload" >&2; exit 1; }
  echo "==> Creating / updating GitHub release $RELEASE_TAG"
  if gh release view "$RELEASE_TAG" -R aneesh-pradhan/xylitol >/dev/null 2>&1; then
    gh release upload "$RELEASE_TAG" \
      "$OUT_DIR/$LK2ND_NAME" \
      "$OUT_DIR/${ROOTFS_NAME}.zst" \
      "$OUT_DIR/SHA256SUMS" \
      "$OUT_DIR/FLASH.md" \
      -R aneesh-pradhan/xylitol --clobber
  else
    gh release create "$RELEASE_TAG" \
      "$OUT_DIR/$LK2ND_NAME" \
      "$OUT_DIR/${ROOTFS_NAME}.zst" \
      "$OUT_DIR/SHA256SUMS" \
      "$OUT_DIR/FLASH.md" \
      -R aneesh-pradhan/xylitol \
      --title "postmarketOS Phosh for perry (${DATE_UTC})" \
      --notes-file "$OUT_DIR/FLASH.md"
  fi
  echo "Release URL:"
  gh release view "$RELEASE_TAG" -R aneesh-pradhan/xylitol --json url -q .url
fi
