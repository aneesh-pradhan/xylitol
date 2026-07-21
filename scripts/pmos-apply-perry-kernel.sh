#!/usr/bin/env bash
# Apply xylitol perry DTB/panel carry onto the local pmbootstrap pmaports
# linux-postmarketos-qcom-msm89x7 package (legacy published-image path).
#
# Patches are copied from the canonical custom-kernel tree:
#   pmos/linux-motorola-perry/patches/
# Overlay APKBUILD.overlay + kconfig panel enables still live under
#   pmos/linux-postmarketos-qcom-msm89x7/
#
# Safe: only touches local pmaports; never flashes; never touches persist/modemst*.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY="$XYLITOL_ROOT/pmos/linux-postmarketos-qcom-msm89x7"
# Canonical DT/panel patches (single source of truth).
PATCH_SRC="$XYLITOL_ROOT/pmos/linux-motorola-perry/patches"

# Resolve pmaports from pmbootstrap config
if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

PKG="$PMAPORTS/device/testing/linux-postmarketos-qcom-msm89x7"
if [[ ! -f "$PKG/APKBUILD" ]]; then
  echo "ERROR: kernel package not found at $PKG" >&2
  exit 1
fi

echo "Applying perry kernel overlay to: $PKG"

# Backup original APKBUILD/config once
mkdir -p "$PKG/.xylitol-upstream"
if [[ ! -f "$PKG/.xylitol-upstream/APKBUILD" ]]; then
  cp -a "$PKG/APKBUILD" "$PKG/.xylitol-upstream/APKBUILD"
  cp -a "$PKG/config-postmarketos-qcom-msm89x7.aarch64" \
        "$PKG/.xylitol-upstream/config-postmarketos-qcom-msm89x7.aarch64"
  echo "Saved upstream copies under $PKG/.xylitol-upstream/"
fi

if [[ ! -d "$PATCH_SRC" ]]; then
  echo "ERROR: canonical patches missing at $PATCH_SRC" >&2
  exit 1
fi

# Copy kernel patches from linux-motorola-perry (not the legacy overlay copies)
shopt -s nullglob
patches=( "$PATCH_SRC"/000*.patch )
if (( ${#patches[@]} < 6 )); then
  echo "ERROR: expected ≥6 patches in $PATCH_SRC, found ${#patches[@]}" >&2
  exit 1
fi
cp -a "${patches[@]}" "$PKG/"
# Keep overlay dir mirrors in sync for anyone browsing that folder
cp -a "${patches[@]}" "$OVERLAY/"

# Install overlay APKBUILD (sha512sums empty until checksum)
cp -a "$OVERLAY/APKBUILD.overlay" "$PKG/APKBUILD"

# Enable perry panel in kconfig
CFG="$PKG/config-postmarketos-qcom-msm89x7.aarch64"
if ! grep -q '^CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V1_TIANMA=' "$CFG"; then
  if grep -q '^CONFIG_DRM_PANEL_MOTOROLA_MONTANA_R63350_TIANMA=m$' "$CFG"; then
    sed -i '/^CONFIG_DRM_PANEL_MOTOROLA_MONTANA_R63350_TIANMA=m$/a CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V1_TIANMA=m' "$CFG"
  else
    echo "ERROR: could not find montana panel config line to insert after" >&2
    exit 1
  fi
fi

# Ofilm 499v0 panel (this unit's actual panel; keep Tianma built too)
if ! grep -q '^CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V0_OFILM=' "$CFG"; then
  sed -i '/^CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V1_TIANMA=m$/i CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V0_OFILM=m' "$CFG"
fi

echo "Overlay files installed. Next:"
echo "  export PATH=\"\$HOME/bin:\$PATH\""
echo "  pmbootstrap checksum linux-postmarketos-qcom-msm89x7"
echo "  pmbootstrap build linux-postmarketos-qcom-msm89x7"
echo
echo "Verify DTB after build:"
echo "  pmbootstrap export"
echo "  # or inspect chroot pkg: find ~/.local or work dir for msm8917-motorola-perry.dtb"
