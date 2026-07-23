#!/usr/bin/env bash
# Install device-motorola-perry into the live pmaports tree (scaffold / Phase B).
# Safe: touches only local pmaports. Never flashes. Never touches persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/device-motorola-perry"

if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

# Upstream still ships archived 3.18 perry aports under the same pkgnames —
# remove them from this local pmaports checkout so testing/ wins.
for archived in \
  "$PMAPORTS/device/archived/device-motorola-perry" \
  "$PMAPORTS/device/archived/linux-motorola-perry"
do
  if [[ -d "$archived" ]]; then
    echo "Removing local archived conflict: $archived"
    rm -rf "$archived"
  fi
done

DEST="$PMAPORTS/device/testing/device-motorola-perry"
echo "pmaports  : $PMAPORTS"
echo "aport dst : $DEST"

mkdir -p "$DEST"
cp -v "$APORT_SRC"/APKBUILD \
  "$APORT_SRC"/deviceinfo \
  "$APORT_SRC"/modules-initfs \
  "$APORT_SRC"/50-perry-wlr.conf \
  "$APORT_SRC"/50-perry-usb-nosuspend.rules \
  "$APORT_SRC"/60-perry-emmc-scheduler.rules \
  "$APORT_SRC"/80-device-motorola-perry.preset \
  "$APORT_SRC"/ipa-simple-s5k4h8.yaml \
  "$APORT_SRC"/ipa-simple-ov5695.yaml \
  "$DEST/"

echo
echo "OK. Next:"
echo "  pmbootstrap checksum device-motorola-perry"
echo "  pmbootstrap build    device-motorola-perry"
echo "See docs/perry-custom-kernel-plan.md before flashing."
