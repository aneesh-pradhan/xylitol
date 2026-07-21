#!/usr/bin/env bash
# Install the local-only firmware-motorola-perry-nv pmaport into the live
# pmaports tree, drop perry's WCNSS Wi-Fi NV blob next to it, and checksum.
#
# This is the DURABLE Wi-Fi fix: the resulting package installs the NV into
# the rootfs at build time, so it survives `pmbootstrap install` (unlike
# scripts/pmos-install-wcnss-nv.sh, which patches a running device and is lost
# on the next rootfs regen). After running this:
#
#   pmbootstrap build firmware-motorola-perry-nv
#   pmbootstrap install --add firmware-motorola-perry-nv   # pulls it into the rootfs
#
# The NV blob is proprietary — it is copied from a LOCAL source into the live
# pmaports aport dir. It is never committed to xylitol (.gitignore blocks
# *.bin) and never fetched from the network.
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

# Locate the NV blob locally: stable backup copy first, then the Lineage build
# output (out/ is wiped on clean builds), then an explicit override.
SRC=""
for cand in \
  "$HOME/android/backups/perry/WCNSS_qcom_wlan_nv.perry.bin" \
  "$HOME/android/lineage/out/target/product/perry/vendor/etc/wifi/WCNSS_qcom_wlan_nv.bin" \
  "${WCNSS_NV_SRC:-}" ; do
  if [[ -n "$cand" && -f "$cand" ]]; then SRC="$cand"; break; fi
done
if [[ -z "$SRC" ]]; then
  echo "ERROR: perry WCNSS NV not found locally." >&2
  echo "  Set WCNSS_NV_SRC=/path/to/WCNSS_qcom_wlan_nv.bin and retry." >&2
  exit 1
fi

echo "pmaports  : $PMAPORTS"
echo "aport dst : $DEST"
echo "NV source : $SRC"

mkdir -p "$DEST"
cp -v "$APORT_SRC/APKBUILD" "$DEST/APKBUILD"
cp -v "$SRC" "$DEST/WCNSS_qcom_wlan_nv.bin"

# Checksum so abuild accepts the local source. Prefer pmbootstrap on PATH.
if command -v pmbootstrap >/dev/null 2>&1; then
  pmbootstrap checksum firmware-motorola-perry-nv
  echo
  echo "OK. Now build + pull into the rootfs:"
  echo "  pmbootstrap build firmware-motorola-perry-nv"
  echo "  pmbootstrap install --add firmware-motorola-perry-nv"
else
  echo
  echo "pmbootstrap not on PATH — finish manually:"
  echo "  pmbootstrap checksum firmware-motorola-perry-nv"
  echo "  pmbootstrap build    firmware-motorola-perry-nv"
  echo "  pmbootstrap install  --add firmware-motorola-perry-nv"
fi
