#!/usr/bin/env bash
# Install the firmware-motorola-perry-nv pmaport into the live pmaports tree.
#
# This is the DURABLE Wi-Fi fix: the package installs perry's WCNSS NV into the
# rootfs at build time (at the mainline DTS path), so Wi-Fi survives
# `pmbootstrap install` — unlike scripts/pmos-install-wcnss-nv.sh, which patches
# a running device and is lost on the next rootfs regen.
#
# The APKBUILD downloads perry's firmware from the same community mirror
# pmaports already pins (checksum baked in) — nothing proprietary is committed
# to xylitol. After running this:
#
#   pmbootstrap build   firmware-motorola-perry-nv
#   pmbootstrap install --add firmware-motorola-perry-nv
#
# Prefer your device's OWN stock NV? That blob differs from the mirror's
# (RF/regulatory cal only). Install it on a running device with
# scripts/pmos-install-wcnss-nv.sh, or drop it in and re-checksum — see
# docs/pmos.md step 6.
#
# Safe: touches only the local pmaports tree. Never flashes, never touches the
# device or persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/firmware-motorola-perry-nv"

# Resolve pmaports from pmbootstrap config (same logic as the kernel script).
if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

DEST="$PMAPORTS/firmware/firmware-motorola-perry-nv"

echo "pmaports  : $PMAPORTS"
echo "aport dst : $DEST"

mkdir -p "$DEST"
cp -v "$APORT_SRC/APKBUILD" "$DEST/APKBUILD"

echo
echo "OK. Build + pull into the rootfs (the blob is fetched + checksum-verified"
echo "at build time — no manual download):"
echo "  pmbootstrap build   firmware-motorola-perry-nv"
echo "  pmbootstrap install --add firmware-motorola-perry-nv"
