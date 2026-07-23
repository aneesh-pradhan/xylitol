#!/usr/bin/env bash
# Seed linux-motorola-perry into live pmaports (scaffold / Phase B).
#
# Copies the custom kernel APKBUILD, seeds defconfig from the upstream msm89x7
# config (until we diverge), and copies perry DTS/panel patches from
# pmos/linux-motorola-perry/patches/ (synced from the msm89x7 overlay carry).
#
# Safe: local pmaports only. Never flashes. Never touches persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/linux-motorola-perry"
PATCH_DIR="$APORT_SRC/patches"

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

UPSTREAM_CFG="$PMAPORTS/device/testing/linux-postmarketos-qcom-msm89x7/config-postmarketos-qcom-msm89x7.aarch64"
DEST="$PMAPORTS/device/testing/linux-motorola-perry"

echo "pmaports  : $PMAPORTS"
echo "aport dst : $DEST"

mkdir -p "$DEST"
cp -v "$APORT_SRC/APKBUILD" "$DEST/"

if [[ -f "$APORT_SRC/config-motorola-perry.aarch64" ]]; then
  cp -v "$APORT_SRC/config-motorola-perry.aarch64" "$DEST/"
elif [[ -f "$UPSTREAM_CFG" ]]; then
  cp -v "$UPSTREAM_CFG" "$DEST/config-motorola-perry.aarch64"
  cp -v "$UPSTREAM_CFG" "$APORT_SRC/config-motorola-perry.aarch64"
  echo "Seeded config from upstream msm89x7 defconfig (not yet perry-tuned)."
else
  echo "WARNING: no defconfig found — place config-motorola-perry.aarch64 in $APORT_SRC" >&2
fi

shopt -s nullglob
# Match 0001..9999 style quilt patches (not only 000*).
for p in "$PATCH_DIR"/[0-9][0-9][0-9][0-9]-*.patch; do
  cp -v "$p" "$DEST/"
done

echo
echo "OK. Next:"
echo "  pmbootstrap checksum linux-motorola-perry"
echo "  pmbootstrap build    linux-motorola-perry"
echo "See docs/perry-custom-kernel-plan.md (Phase B gate before flash)."
