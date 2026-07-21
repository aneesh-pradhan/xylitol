#!/usr/bin/env bash
# Runtime install of /etc/deviceinfo on a booted perry pmOS device (USB-net SSH).
#
# Same durable Blocker-A fix as the deviceinfo-motorola-perry pmaport, but for a
# live rootfs without pmbootstrap install. After writing, re-runs mkinitfs so
# /boot/extlinux/extlinux.conf is regenerated with:
#   fdt /msm8917-motorola-perry.dtb
#
# Usage (host, phone on USB-net at 172.16.42.1):
#   ./scripts/pmos-install-perry-deviceinfo.sh
#   PMOS_SUDO_PASSWORD=... ./scripts/pmos-install-perry-deviceinfo.sh user@host
#
# Requires: ssh key auth. Never touches persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$XYLITOL_ROOT/pmos/deviceinfo-motorola-perry/deviceinfo"
TARGET="${1:-xylitol@172.16.42.1}"
PW="${PMOS_SUDO_PASSWORD:-xylitol}"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: missing $SRC" >&2
  exit 1
fi

# Bring up USB-net IP if the cdc_ncm iface is present (best-effort).
for n in /sys/class/net/*; do
  if grep -q cdc_ncm "$n/device/uevent" 2>/dev/null; then
    sudo ip addr add 172.16.42.2/24 dev "$(basename "$n")" 2>/dev/null || true
    sudo ip link set "$(basename "$n")" up 2>/dev/null || true
    break
  fi
done

B64="$(base64 -w0 < "$SRC")"

echo "Installing /etc/deviceinfo on $TARGET and regenerating extlinux..."
ssh -o ConnectTimeout=8 -o BatchMode=yes "$TARGET" \
  "B64='$B64' PW='$PW' sh -s" <<'REMOTE'
set -e
S() { echo "$PW" | sudo -S -p '' "$@" ; }
echo "$B64" | base64 -d > /tmp/deviceinfo.perry
S cp /tmp/deviceinfo.perry /etc/deviceinfo
S chmod 644 /etc/deviceinfo
S mkinitfs

CONF=/boot/extlinux/extlinux.conf

# Derive the expected DTB basename from the override we just installed, so the
# checks below track deviceinfo_dtb instead of a hardcoded name.
# shellcheck disable=SC1091
. /etc/deviceinfo
[ -n "${deviceinfo_dtb:-}" ] || { echo "FAIL: /etc/deviceinfo did not set deviceinfo_dtb" >&2; exit 1; }
DTB_STEM="$(basename "$deviceinfo_dtb")"   # e.g. msm8917-motorola-perry

# (1) Exactly one DTB must resolve, the same way boot-deploy's find_all_dtbs does.
# 0 => perry DTB missing from /boot/dtbs (wrong kernel) => boot-deploy emits no
# fdt line at all; >1 => boot-deploy emits 'fdtdir /'. Both brick on reboot.
count=0
for f in $deviceinfo_dtb; do
  count=$((count + $(find /boot -path "/boot/dtbs*/$f.dtb" | wc -l)))
done
if [ "$count" -ne 1 ]; then
  echo "FAIL: deviceinfo_dtb resolves to $count DTBs under /boot/dtbs (need exactly 1)." >&2
  echo "      0 = perry DTB not installed (wrong kernel?); >1 = boot-deploy would emit fdtdir." >&2
  exit 1
fi

# (2) The regenerated boot line must be an explicit fdt, never fdtdir.
if grep -q 'fdtdir' "$CONF"; then
  echo "FAIL: $CONF still contains 'fdtdir' — lk2nd cannot resolve it (brick on reboot)." >&2
  grep -nE 'fdt|fdtdir' "$CONF" >&2
  exit 1
fi
if ! grep -qF "fdt /$DTB_STEM.dtb" "$CONF"; then
  echo "FAIL: $CONF has no 'fdt /$DTB_STEM.dtb' line after regeneration." >&2
  grep -nE 'fdt|fdtdir' "$CONF" >&2
  exit 1
fi

# (3) The flat DTB the fdt line points at must exist on the boot fs.
[ -f "/boot/$DTB_STEM.dtb" ] || { echo "FAIL: /boot/$DTB_STEM.dtb missing — the fdt line would not resolve." >&2; exit 1; }

echo "PASS: extlinux pinned to 'fdt /$DTB_STEM.dtb' (1 DTB resolved, flat file present, no fdtdir)."
grep -nE 'fdt|fdtdir' "$CONF"
REMOTE

echo "OK — device validated: extlinux uses explicit fdt (survives apk/mkinitfs regen)."
