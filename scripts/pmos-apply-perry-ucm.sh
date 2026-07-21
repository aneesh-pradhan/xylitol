#!/usr/bin/env bash
# Install the alsa-ucm-motorola-perry pmaport into the live pmaports tree.
#
# This is the DURABLE audio fix: the package installs perry's ALSA UCM2 profile
# (+ a WirePlumber libcamera-monitor disable) into the rootfs at build time, so
# audio survives `pmbootstrap install` — unlike scripts/pmos-install-perry-ucm.sh,
# which patches a running device and is lost on the next rootfs regen.
#
# After running this:
#
#   pmbootstrap build   alsa-ucm-motorola-perry
#   pmbootstrap install --add alsa-ucm-motorola-perry
#
# Headless bring-up only: also `loginctl enable-linger <user>` on the device so
# pipewire/wireplumber persist across SSH sessions (a real phone UI session
# keeps them alive; not needed there). That is runtime state, not packaged.
#
# Safe: touches only the local pmaports tree. Never flashes, never touches the
# device or persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/alsa-ucm-motorola-perry"

# Resolve pmaports from pmbootstrap config (same logic as the other scripts).
if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

DEST="$PMAPORTS/device/testing/alsa-ucm-motorola-perry"

echo "pmaports  : $PMAPORTS"
echo "aport dst : $DEST"

mkdir -p "$DEST"
cp -v "$APORT_SRC/APKBUILD" \
      "$APORT_SRC/motorola-perry.conf" \
      "$APORT_SRC/50-perry-disable-libcamera.conf" \
      "$DEST/"

echo
echo "OK. Build + pull into the rootfs:"
echo "  pmbootstrap build   alsa-ucm-motorola-perry"
echo "  pmbootstrap install --add alsa-ucm-motorola-perry"
