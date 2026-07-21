#!/usr/bin/env bash
# Inject the framebuffer-wait-timeout patch into the local pmaports
# postmarketos-initramfs aport, then checksum it so `pmbootstrap build
# postmarketos-initramfs` picks it up.
#
# WHY: setup_framebuffer() in init_functions.sh gives up on /dev/fb0 after a
# hardcoded 10s and skips set_framebuffer_mode() -- but perry's Ofilm 499v0
# DPU/DSI DRM driver doesn't bind until ~27s in, so perry never gets a splash
# console. The patch adds deviceinfo_framebuffer_wait_seconds (default 10,
# unchanged for every other device); perry's own deviceinfo raises it via
# device-motorola-perry. See pmos/postmarketos-initramfs/0001-*.patch,
# docs/perry-custom-kernel-plan.md P1.5, docs/porting-log.md 2026-07-20
# "Retire Solution-2 DTB hacks".
#
#   ./scripts/pmos-apply-initramfs-perry.sh
#   pmbootstrap build postmarketos-initramfs
#
# Idempotent. Touches only the local pmaports tree (a git checkout pmbootstrap
# manages). Never flashes here; never touches persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$XYLITOL_ROOT/pmos/postmarketos-initramfs/0001-make-framebuffer-wait-timeout-device-configurable.patch"

if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

APORT="$PMAPORTS/main/postmarketos-initramfs"
APKBUILD="$APORT/APKBUILD"
[[ -f "$PATCH" ]]    || { echo "ERROR: missing $PATCH" >&2; exit 1; }
[[ -f "$APKBUILD" ]] || { echo "ERROR: postmarketos-initramfs APKBUILD not found at $APKBUILD" >&2; exit 1; }

PATCH_BASE="$(basename "$PATCH")"
echo "pmaports : $PMAPORTS"
echo "aport    : $APORT"
echo "patch    : $PATCH_BASE"

cp -v "$PATCH" "$APORT/$PATCH_BASE"

# Bump pkgrel 0 -> 1 so our local build is unambiguous vs. upstream r0.
# Idempotent: the sed only matches the pristine 'pkgrel=0'.
sed -i 's/^pkgrel=0$/pkgrel=1/' "$APKBUILD"
echo "pkgrel now: $(grep '^pkgrel=' "$APKBUILD")"

# This APKBUILD ships plain files (no tarball), so it never sets builddir=
# and abuild's default_prepare() has nowhere to apply our .patch entry
# ("Is $builddir set correctly?"). $srcdir (abuild's default) is populated
# with *symlinks* back into $startdir for local, non-archive sources, and
# `patch` refuses to edit through a symlink ("not a regular file") -- so
# point builddir at $startdir instead, where init_functions.sh is a real
# file. $srcdir/init_functions.sh (used by build()/package()) is a symlink
# to that same path, so it picks up the patched content automatically.
if ! grep -q '^builddir=' "$APKBUILD"; then
  sed -i '/^source="/i builddir="$startdir"' "$APKBUILD"
  echo "inserted builddir=\"\$startdir\""
fi

# Add the patch to source= (before the closing quote of the source block),
# unless it is already listed.
if grep -qF "$PATCH_BASE" "$APKBUILD"; then
  echo "source= already lists $PATCH_BASE — skipping insert"
else
  awk -v p="$PATCH_BASE" '
    /^source="/ {print; insrc=1; next}
    insrc && /^[ \t]*"[ \t]*$/ {print "\t" p; print; insrc=0; next}
    {print}
  ' "$APKBUILD" > "$APKBUILD.tmp" && mv "$APKBUILD.tmp" "$APKBUILD"
  echo "inserted $PATCH_BASE into source="
fi

echo
echo "Re-checksumming postmarketos-initramfs (adds sha512 for the patch)..."
pmbootstrap checksum postmarketos-initramfs

echo
echo "OK. Now build:"
echo "  pmbootstrap build postmarketos-initramfs"
echo "Perry's own wait override lives in device-motorola-perry/deviceinfo"
echo "(deviceinfo_framebuffer_wait_seconds)."
