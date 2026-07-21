#!/usr/bin/env bash
# Install the deviceinfo-motorola-perry pmaport into the live pmaports tree.
#
# DURABLE Blocker-A fix: /etc/deviceinfo pins deviceinfo_dtb to the single perry
# DTB so boot-deploy's create_extlinux_config emits
#   fdt /msm8917-motorola-perry.dtb
# instead of fdtdir / (which lk2nd cannot resolve without a perry device node).
# Survives apk upgrades / mkinitfs / pmbootstrap install.
#
#   ./scripts/pmos-apply-perry-deviceinfo.sh
#   pmbootstrap build   deviceinfo-motorola-perry
#   pmbootstrap install --add deviceinfo-motorola-perry
#
# On a running device without rebuilding the image, use
# scripts/pmos-install-perry-deviceinfo.sh instead.
#
# Safe: touches only the local pmaports tree. Never flashes, never touches
# persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/deviceinfo-motorola-perry"

if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

DEST="$PMAPORTS/device/testing/deviceinfo-motorola-perry"

echo "pmaports  : $PMAPORTS"
echo "aport dst : $DEST"

mkdir -p "$DEST"
cp -v "$APORT_SRC/APKBUILD" "$DEST/APKBUILD"
cp -v "$APORT_SRC/deviceinfo" "$DEST/deviceinfo"

echo
echo "OK. Build + pull into the rootfs:"
echo "  pmbootstrap checksum deviceinfo-motorola-perry"
echo "  pmbootstrap build    deviceinfo-motorola-perry"
echo "  pmbootstrap install  --add deviceinfo-motorola-perry"
