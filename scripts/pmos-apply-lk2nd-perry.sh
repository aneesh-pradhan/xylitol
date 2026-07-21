#!/usr/bin/env bash
# Inject the perry lk2nd device-node patch into the local pmaports lk2nd aport,
# then checksum it so `pmbootstrap build lk2nd` picks it up.
#
# WHY: perry (XT1765/MSM8917) has no lk2nd device node upstream, so lk2nd shows
# "Unknown (FIXME!)" and cannot resolve `fdtdir /` (lk2nd_device_get_dtb_hints()
# is NULL). The patch adds a motorola-perry node to msm8917-mtp.dts alongside
# its siblings nora/hannah. See pmos/lk2nd/0001-*.patch and
# docs/pmos-lk2nd-perry-node.md.
#
#   ./scripts/pmos-apply-lk2nd-perry.sh
#   pmbootstrap build lk2nd
#   # then flash: see docs/pmos-lk2nd-perry-node.md (device-side, gated)
#
# Idempotent. Touches only the local pmaports tree (a git checkout pmbootstrap
# manages). Never flashes here; never touches persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$XYLITOL_ROOT/pmos/lk2nd/0001-device-add-motorola-perry-msm8917-node.patch"

if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

APORT="$PMAPORTS/main/lk2nd"
APKBUILD="$APORT/APKBUILD"
[[ -f "$PATCH" ]]   || { echo "ERROR: missing $PATCH" >&2; exit 1; }
[[ -f "$APKBUILD" ]] || { echo "ERROR: lk2nd APKBUILD not found at $APKBUILD" >&2; exit 1; }

PATCH_BASE="$(basename "$PATCH")"
echo "pmaports : $PMAPORTS"
echo "aport    : $APORT"
echo "patch    : $PATCH_BASE"

cp -v "$PATCH" "$APORT/$PATCH_BASE"

# Bump pkgrel 2 -> 3 so our local build is unambiguous vs the upstream r2 and
# lk2nd reports 22.0-r3-postmarketos on-device (LK2ND_VERSION uses pkgrel).
# Idempotent: the sed only matches the pristine 'pkgrel=2'.
sed -i 's/^pkgrel=2$/pkgrel=3/' "$APKBUILD"
echo "pkgrel now: $(grep '^pkgrel=' "$APKBUILD")"

# Add the patch to source= (before the closing quote of the source block),
# unless it is already listed. The source block is:
#   source="
#           $pkgname-$pkgver.tar.gz::https://...
#   "
if grep -qF "$PATCH_BASE" "$APKBUILD"; then
  echo "source= already lists $PATCH_BASE — skipping insert"
else
  # Insert the patch line before the first standalone closing quote that ends
  # the source block (the first lone '"' after the 'source="' line).
  awk -v p="$PATCH_BASE" '
    /^source="/ {print; insrc=1; next}
    insrc && /^"/ {print "\t" p; print; insrc=0; next}
    {print}
  ' "$APKBUILD" > "$APKBUILD.tmp" && mv "$APKBUILD.tmp" "$APKBUILD"
  echo "inserted $PATCH_BASE into source="
fi

echo
echo "Re-checksumming lk2nd (adds sha512 for the patch)..."
pmbootstrap checksum lk2nd

echo
echo "OK. Now build + (device-side) flash:"
echo "  pmbootstrap build lk2nd"
echo "  # flash per docs/pmos-lk2nd-perry-node.md — reflashes the 'boot' partition"
