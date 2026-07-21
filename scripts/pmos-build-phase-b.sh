#!/usr/bin/env bash
# Phase B + P0: build linux-motorola-perry + device-motorola-perry and produce
# a lean Phosh install image (first-class motorola-perry device).
#
# Does NOT flash. Does NOT touch persist/modemst*.
#
# Usage:
#   ./scripts/pmos-build-phase-b.sh
#
# Env overrides:
#   PMOS_USER / PMOS_PASSWORD  (default: xylitol / xylitol)
#   PMOS_EXTRA_SPACE           (default: 2048 MiB)
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$XYLITOL_ROOT"

PMOS_USER="${PMOS_USER:-xylitol}"
PMOS_PASSWORD="${PMOS_PASSWORD:-xylitol}"
PMOS_EXTRA_SPACE="${PMOS_EXTRA_SPACE:-2048}"
OUT_DIR="$XYLITOL_ROOT/artifacts/pmos-phase-b"
DATE_UTC="$(date -u +%Y-%m-%dT%H%MZ)"

export PATH="${HOME}/bin:${PATH}"
command -v pmbootstrap >/dev/null || {
  echo "ERROR: pmbootstrap not on PATH" >&2
  exit 1
}

mkdir -p "$OUT_DIR"

echo "==> Applying xylitol perry packages into live pmaports"
./scripts/pmos-apply-perry-firmware.sh
./scripts/pmos-apply-perry-ucm.sh
./scripts/pmos-apply-lk2nd-perry.sh
./scripts/pmos-apply-kernel-perry.sh
./scripts/pmos-apply-device-perry.sh

echo "==> pmbootstrap config: device=motorola-perry ui=phosh user=${PMOS_USER}"
pmbootstrap config device motorola-perry
pmbootstrap config ui phosh
pmbootstrap config user "$PMOS_USER"
pmbootstrap config extra_space "$PMOS_EXTRA_SPACE"
pmbootstrap config ssh_keys False
pmbootstrap config hostname perry
pmbootstrap config extra_packages none

echo "==> Checksum + build packages"
pmbootstrap checksum linux-motorola-perry
pmbootstrap checksum device-motorola-perry
pmbootstrap build firmware-motorola-perry-nv
pmbootstrap build alsa-ucm-motorola-perry
pmbootstrap build lk2nd
pmbootstrap build linux-motorola-perry
pmbootstrap build device-motorola-perry

echo "==> pmbootstrap install (Phosh, --no-recommends = P0.2 lean)"
# --zap: clean chroots. --no-recommends: drop firefox/cups/flatpak/etc.
pmbootstrap install --zap --password "$PMOS_PASSWORD" --no-recommends

echo "==> Export images"
pmbootstrap export
EXPORT_DIR="/tmp/postmarketOS-export"
ROOTFS_SRC=""
LK2ND_SRC=""
for cand in \
  "$EXPORT_DIR/motorola-perry.img" \
  "$HOME/pmos/work/chroot_native/home/pmos/rootfs/motorola-perry.img"
do
  if [[ -f "$cand" ]]; then
    ROOTFS_SRC="$cand"
    break
  fi
done
for cand in \
  "$EXPORT_DIR/lk2nd-msm8952.img" \
  "$EXPORT_DIR/lk2nd.img" \
  "$HOME/pmos/work/chroot_rootfs_motorola-perry/boot/lk2nd.img"
do
  if [[ -f "$cand" ]]; then
    LK2ND_SRC="$cand"
    break
  fi
done
[[ -n "$ROOTFS_SRC" ]] || { echo "ERROR: rootfs image not found after export" >&2; exit 1; }
[[ -n "$LK2ND_SRC" ]] || { echo "ERROR: lk2nd image not found after export" >&2; exit 1; }

ROOTFS_NAME="motorola-perry-phosh.img"
LK2ND_NAME="lk2nd-msm8952-perry.img"
cp -v "$ROOTFS_SRC" "$OUT_DIR/$ROOTFS_NAME"
cp -v "$LK2ND_SRC" "$OUT_DIR/$LK2ND_NAME"

echo "==> Sanity-check image (fdt, linger, P0 bits, kernel flavor)"
LOOP="$(sudo losetup -fP --show "$OUT_DIR/$ROOTFS_NAME")"
cleanup_loop() {
  sudo umount /mnt/pmos-b-boot 2>/dev/null || true
  sudo umount /mnt/pmos-b-root 2>/dev/null || true
  sudo losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup_loop EXIT
sudo mkdir -p /mnt/pmos-b-boot /mnt/pmos-b-root
sudo mount "${LOOP}p1" /mnt/pmos-b-boot
sudo mount "${LOOP}p2" /mnt/pmos-b-root

EXTLINUX="$(sudo cat /mnt/pmos-b-boot/extlinux/extlinux.conf)"
echo "$EXTLINUX" | grep -q 'fdt /msm8917-motorola-perry.dtb' \
  || { echo "ERROR: extlinux missing explicit perry fdt" >&2; echo "$EXTLINUX"; exit 1; }
sudo test -f /mnt/pmos-b-boot/msm8917-motorola-perry.dtb \
  || { echo "ERROR: perry DTB missing from boot" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/var/lib/systemd/linger/"$PMOS_USER" \
  || { echo "ERROR: linger marker missing for $PMOS_USER" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/etc/environment.d/50-perry-wlr.conf \
  || { echo "ERROR: WLR env drop-in missing" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/lib/firmware/qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin \
  || { echo "ERROR: WCNSS NV missing" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf \
  || { echo "ERROR: perry UCM missing" >&2; exit 1; }
# Kernel flavor: custom perry package, not generic msm89x7
if ! sudo grep -q motorola-perry /mnt/pmos-b-boot/extlinux/extlinux.conf \
  && ! sudo test -e /mnt/pmos-b-root/usr/share/kernel/motorola-perry/kernel.release; then
  echo "WARNING: could not confirm linux-motorola-perry flavor marker" >&2
fi
sudo cat /mnt/pmos-b-root/usr/share/kernel/motorola-perry/kernel.release 2>/dev/null \
  || sudo ls /mnt/pmos-b-root/usr/share/kernel/ 2>/dev/null || true

if sudo test -s /mnt/pmos-b-root/home/"$PMOS_USER"/.ssh/authorized_keys 2>/dev/null; then
  echo "ERROR: authorized_keys present" >&2
  exit 1
fi
if sudo find /mnt/pmos-b-root/etc/NetworkManager/system-connections \
     -type f -name '*.nmconnection' 2>/dev/null | grep -q .; then
  echo "ERROR: NetworkManager profiles present" >&2
  exit 1
fi

cleanup_loop
trap - EXIT

cat > "$OUT_DIR/FLASH.md" <<EOF
# Phase B — motorola-perry + linux-motorola-perry (${DATE_UTC})

First-class \`device-motorola-perry\` / \`linux-motorola-perry\` Phosh image
with P0 userspace (zram via deviceinfo, \`WLR_DRM_NO_ATOMIC=1\`, lean
\`--no-recommends\`, USB nosuspend udev, service presets).

Default login: **${PMOS_USER}** / **${PMOS_PASSWORD}**
SSH USB-net: \`${PMOS_USER}@172.16.42.1\` (host \`172.16.42.2/24\`,
\`nmcli device set <iface> managed no\`).

Sacred: never touch \`persist\` / \`modemst1\` / \`modemst2\`.

\`\`\`bash
# From stock fastboot:
fastboot flash boot ${LK2ND_NAME}
# Into lk2nd fastboot (product: lk2nd-msm8952):
fastboot flash userdata ${ROOTFS_NAME}
fastboot continue
\`\`\`

Build: \`scripts/pmos-build-phase-b.sh\`
EOF

(
  cd "$OUT_DIR"
  sha256sum "$LK2ND_NAME" "$ROOTFS_NAME" > SHA256SUMS
)

echo
echo "OK. Phase B artifacts in $OUT_DIR"
ls -lh "$OUT_DIR"
echo "Flash with FLASH.md — then measure baselines (systemd-analyze / free -h)."
