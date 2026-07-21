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
TARGET="${1:-aneesh@172.16.42.1}"
PW="${PMOS_SUDO_PASSWORD:-147147}"

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
grep -E 'fdt|fdtdir' /boot/extlinux/extlinux.conf
REMOTE

echo "OK — expect: fdt /msm8917-motorola-perry.dtb (not fdtdir /)"
