#!/usr/bin/env bash
# Flash Phase B image to perry (userdata + optional lk2nd).
# PARKED 2026-07-21 — do not run unless explicitly resuming device flash.
# Sacred: never touches persist / modemst1 / modemst2.
#
# Put the phone in lk2nd fastboot first:
#   - From running pmOS: reboot, hold Volume-Down
#   - Or: stock/aboot fastboot → flash lk2nd → reboot to lk2nd fastboot
#
# Usage:
#   ./scripts/pmos-flash-phase-b.sh           # rootfs only (lk2nd already good)
#   ./scripts/pmos-flash-phase-b.sh --lk2nd  # also reflash boot with lk2nd
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$XYLITOL_ROOT/artifacts/pmos-phase-b"
ROOTFS="$OUT/motorola-perry-phosh.img"
LK2ND="$OUT/lk2nd-msm8952-perry.img"
DO_LK2ND=0
for arg in "$@"; do
  case "$arg" in
    --lk2nd) DO_LK2ND=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

[[ -f "$ROOTFS" ]] || { echo "ERROR: missing $ROOTFS — run scripts/pmos-build-phase-b.sh first" >&2; exit 1; }
[[ -f "$LK2ND" ]] || { echo "ERROR: missing $LK2ND" >&2; exit 1; }

export PATH="${HOME}/bin:${PATH}"
command -v fastboot >/dev/null || { echo "ERROR: fastboot not on PATH" >&2; exit 1; }

echo "==> Waiting for fastboot device (hold Vol-Down through reboot into lk2nd)..."
until fastboot devices 2>/dev/null | grep -q .; do
  sleep 1
done
fastboot devices -l
PRODUCT="$(fastboot getvar product 2>&1 | awk -F': ' '/^product:/{print $2}' | tr -d '\r')"
echo "product=$PRODUCT"

if [[ "$DO_LK2ND" -eq 1 ]]; then
  echo "==> Flashing lk2nd → boot"
  fastboot flash boot "$LK2ND"
  echo "Reboot into lk2nd fastboot again if product is not lk2nd-msm8952, then re-run without --lk2nd."
fi

if [[ "$PRODUCT" != *lk2nd* ]]; then
  echo "WARNING: product='$PRODUCT' — expected lk2nd-msm8952 before flash_rootfs." >&2
  echo "Flashing userdata outside lk2nd can soft-brick. Aborting." >&2
  exit 1
fi

echo "==> Flashing rootfs → userdata (~2–3 min, destructive to userdata only)"
fastboot flash userdata "$ROOTFS"
echo "==> Booting"
fastboot continue
echo "OK. Wait for Phosh + USB-net, then: ssh xylitol@172.16.42.1  (pw: xylitol)"
echo "Host tip: nmcli device set <cdc_ncm_iface> managed no"
