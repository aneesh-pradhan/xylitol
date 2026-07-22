#!/usr/bin/env bash
# Phase B + P0: build linux-motorola-perry + device-motorola-perry and produce
# a Phosh install image (first-class motorola-perry device).
#
# Does NOT flash. Does NOT touch persist/modemst*.
#
# Usage:
#   ./scripts/pmos-build-phase-b.sh              # lean (default; --no-recommends)
#   LEAN=0 ./scripts/pmos-build-phase-b.sh       # full Phosh app suite (release)
#
# Env overrides:
#   PMOS_USER / PMOS_PASSWORD  (default: xylitol / xylitol)
#   PMOS_EXTRA_SPACE           (default: 2048 MiB)
#   LEAN=0|1                   default 1: pmbootstrap --no-recommends (P0.2).
#                              LEAN=0: install recommends (Calculator, Calendar,
#                              Console, Firefox-ESR, Chatty, Calls, …) matching
#                              the prior complete Phosh release UX.
#   ENABLE_P15=1               DANGEROUS: apply P1.5 framebuffer-wait patch
#                              (known boot hang on perry — Bisect D 2026-07-22).
#                              Default is OFF (unpatched initramfs).
#   DROP_P15=1                 Legacy alias for default (no-op / force-off).
#   BISECT_TAG=...             Optional artifact name suffix (raw/sparse).
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$XYLITOL_ROOT"

PMOS_USER="${PMOS_USER:-xylitol}"
PMOS_PASSWORD="${PMOS_PASSWORD:-xylitol}"
PMOS_EXTRA_SPACE="${PMOS_EXTRA_SPACE:-2048}"
LEAN="${LEAN:-1}"
# Default OFF: P1.5 hard-hangs perry (phase-b-boot-hang-bisect.md Bisect D).
ENABLE_P15="${ENABLE_P15:-0}"
if [[ "${DROP_P15:-}" == "1" ]]; then
  ENABLE_P15=0
fi
OUT_DIR="$XYLITOL_ROOT/artifacts/pmos-phase-b"
DATE_UTC="$(date -u +%Y-%m-%dT%H%MZ)"
BISECT_TAG="${BISECT_TAG:-}"

export PATH="${HOME}/bin:${PATH}"
command -v pmbootstrap >/dev/null || {
  echo "ERROR: pmbootstrap not on PATH" >&2
  exit 1
}

mkdir -p "$OUT_DIR"

if [[ -n "${PMAPORTS:-}" ]]; then
  :
elif [[ -f "${HOME}/.config/pmbootstrap_v3.cfg" ]]; then
  PMAPORTS="$(awk -F' = ' '/^aports = /{print $2; exit}' "${HOME}/.config/pmbootstrap_v3.cfg")"
else
  echo "ERROR: set PMAPORTS or run pmbootstrap init first" >&2
  exit 1
fi

echo "==> Applying xylitol perry packages into live pmaports"
./scripts/pmos-apply-perry-firmware.sh
./scripts/pmos-apply-perry-ucm.sh
./scripts/pmos-apply-lk2nd-perry.sh
./scripts/pmos-apply-kernel-perry.sh
./scripts/pmos-apply-device-perry.sh

if [[ "$ENABLE_P15" == "1" ]]; then
  echo "==> ENABLE_P15=1: applying P1.5 (KNOWN HANG on perry — research only)"
  ./scripts/pmos-apply-initramfs-perry.sh
else
  echo "==> P1.5 off (default): restore unpatched postmarketos-initramfs"
  # Undo any prior pmos-apply-initramfs-perry.sh edits in this local pmaports.
  if [[ -d "$PMAPORTS/.git" ]]; then
    git -C "$PMAPORTS" checkout -- main/postmarketos-initramfs/APKBUILD
    rm -f "$PMAPORTS/main/postmarketos-initramfs/0001-make-framebuffer-wait-timeout-device-configurable.patch"
  else
    echo "ERROR: pmaports is not a git checkout; cannot restore clean initramfs" >&2
    exit 1
  fi
  DEVICEINFO_DST="$PMAPORTS/device/testing/device-motorola-perry/deviceinfo"
  if grep -q 'deviceinfo_framebuffer_wait_seconds' "$DEVICEINFO_DST"; then
    sed -i '/deviceinfo_framebuffer_wait_seconds/d' "$DEVICEINFO_DST"
    echo "stripped deviceinfo_framebuffer_wait_seconds from live pmaports deviceinfo"
  fi
fi

echo "==> pmbootstrap config: device=motorola-perry ui=phosh user=${PMOS_USER}"
pmbootstrap config device motorola-perry
pmbootstrap config ui phosh
pmbootstrap config user "$PMOS_USER"
pmbootstrap config extra_space "$PMOS_EXTRA_SPACE"
pmbootstrap config ssh_keys False
pmbootstrap config hostname perry
pmbootstrap config extra_packages none

echo "==> Checksum + build packages"
pmbootstrap checksum linux-motorola-perry
pmbootstrap checksum device-motorola-perry
pmbootstrap build firmware-motorola-perry-nv --arch aarch64 --lax
pmbootstrap build alsa-ucm-motorola-perry --arch aarch64 --lax
pmbootstrap build lk2nd --lax
# --arch aarch64: this is a noarch package but defaults to building for the
# native host arch; without an explicit aarch64 build+index entry, apk
# silently falls back to the unpatched upstream binary during install.
# --lax: skip post-build zap (this host hits intermittent umount busy races).
if [[ "$ENABLE_P15" == "1" ]]; then
  pmbootstrap build postmarketos-initramfs --arch aarch64 --lax
  pmbootstrap build linux-motorola-perry --lax
  pmbootstrap build device-motorola-perry --lax
else
  # Force rebuild so we do not reuse a previously patched initramfs apk.
  pmbootstrap build postmarketos-initramfs --arch aarch64 --force --lax
  pmbootstrap build device-motorola-perry --force --lax
  pmbootstrap build linux-motorola-perry --force --lax
fi

if [[ "$LEAN" == "1" ]]; then
  echo "==> pmbootstrap install (Phosh, --no-recommends = P0.2 lean)"
else
  echo "==> pmbootstrap install (Phosh, FULL recommends = complete app suite)"
fi
# Ensure no stale chroot mounts (prior --zap umount races on this host).
pmbootstrap shutdown || true

if [[ "$ENABLE_P15" != "1" ]]; then
  # apk installs the *highest* pkgrel present in the local index. Prior bisects
  # leave postmarketos-initramfs-r1 (P1.5 patch) and linux-motorola-perry-r2/r3
  # which would silently win over the packages we just built.
  PKGDIR="${HOME}/pmos/work/packages/edge/aarch64"
  if [[ -d "$PKGDIR" ]]; then
    echo "==> purge conflicting local apks that would win version select"
    sudo rm -fv "$PKGDIR"/postmarketos-initramfs-*-r[1-9]*.apk 2>/dev/null || true
    LINUX_REL="$(awk -F= '/^pkgrel=/{print $2; exit}' \
      "$PMAPORTS/device/testing/linux-motorola-perry/APKBUILD")"
    for apk in "$PKGDIR"/linux-motorola-perry-*.apk; do
      [[ -f "$apk" ]] || continue
      base="$(basename "$apk" .apk)"
      rel="${base##*-r}"
      if [[ "$rel" != "$LINUX_REL" ]]; then
        sudo rm -fv "$apk"
      fi
    done
    pmbootstrap index || true
  fi
fi

# --zap: clean chroots. LEAN=1: --no-recommends drops firefox/cups/flatpak/…
INSTALL_ARGS=(--zap --password "$PMOS_PASSWORD")
if [[ "$LEAN" == "1" ]]; then
  INSTALL_ARGS+=(--no-recommends)
fi
pmbootstrap install "${INSTALL_ARGS[@]}"

echo "==> Export images"
pmbootstrap export
EXPORT_DIR="/tmp/postmarketOS-export"
ROOTFS_SRC=""
LK2ND_SRC=""
for cand in \
  "$EXPORT_DIR/motorola-perry.img" \
  "$HOME/pmos/work/chroot_native/home/pmos/rootfs/motorola-perry.img"
do
  if [[ -f "$cand" ]]; then
    ROOTFS_SRC="$cand"
    break
  fi
done
for cand in \
  "$EXPORT_DIR/lk2nd-msm8952.img" \
  "$EXPORT_DIR/lk2nd.img" \
  "$HOME/pmos/work/chroot_rootfs_motorola-perry/boot/lk2nd.img"
do
  if [[ -f "$cand" ]]; then
    LK2ND_SRC="$cand"
    break
  fi
done
[[ -n "$ROOTFS_SRC" ]] || { echo "ERROR: rootfs image not found after export" >&2; exit 1; }
[[ -n "$LK2ND_SRC" ]] || { echo "ERROR: lk2nd image not found after export" >&2; exit 1; }

if [[ -n "$BISECT_TAG" ]]; then
  ROOTFS_NAME="motorola-perry-phosh-${BISECT_TAG}.img"
  SPARSE_NAME="motorola-perry-phosh-${BISECT_TAG}.sparse.img"
else
  ROOTFS_NAME="motorola-perry-phosh.img"
  SPARSE_NAME="motorola-perry-phosh.sparse.img"
fi
LK2ND_NAME="lk2nd-msm8952-perry.img"
cp -v "$ROOTFS_SRC" "$OUT_DIR/$ROOTFS_NAME"
cp -v "$LK2ND_SRC" "$OUT_DIR/$LK2ND_NAME"

# Reject FORCE-as-NORMAL (poisoned package cache / wrong export).
# grep -a on file — avoid `strings | grep -q` under pipefail (SIGPIPE false results).
if grep -aFq 'Fastboot mode was forced with compile-time flag.' "$OUT_DIR/$LK2ND_NAME"; then
  echo "ERROR: $LK2ND_NAME is a FORCE-FASTBOOT build — refusing to ship as NORMAL" >&2
  echo "Rebuild lk2nd without LK2ND_FORCE_FASTBOOT (pmbootstrap build lk2nd --force)." >&2
  exit 1
fi

echo "==> Regenerating sparse image (always fresh from this raw)"
command -v img2simg >/dev/null || {
  echo "ERROR: img2simg required (android-sdk-libsparse-utils)" >&2
  exit 1
}
img2simg "$OUT_DIR/$ROOTFS_NAME" "$OUT_DIR/$SPARSE_NAME"

echo "==> Sanity-check image (fdt, linger, P0 bits, kernel flavor)"
# ro,noload: avoid dirtying raw image SHA via journal/superblock writes
LOOP="$(sudo losetup -fP --show "$OUT_DIR/$ROOTFS_NAME")"
cleanup_loop() {
  sudo umount /mnt/pmos-b-boot 2>/dev/null || true
  sudo umount /mnt/pmos-b-root 2>/dev/null || true
  sudo losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup_loop EXIT
sudo mkdir -p /mnt/pmos-b-boot /mnt/pmos-b-root
sudo mount -o ro "${LOOP}p1" /mnt/pmos-b-boot
# root is ext4: noload avoids journal replay that dirties the raw image SHA
sudo mount -o ro,noload "${LOOP}p2" /mnt/pmos-b-root || \
  sudo mount -o ro "${LOOP}p2" /mnt/pmos-b-root

EXTLINUX="$(sudo cat /mnt/pmos-b-boot/extlinux/extlinux.conf)"
echo "$EXTLINUX" | grep -q 'fdt /msm8917-motorola-perry.dtb' \
  || { echo "ERROR: extlinux missing explicit perry fdt" >&2; echo "$EXTLINUX"; exit 1; }
sudo test -f /mnt/pmos-b-boot/msm8917-motorola-perry.dtb \
  || { echo "ERROR: perry DTB missing from boot" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/var/lib/systemd/linger/"$PMOS_USER" \
  || { echo "ERROR: linger marker missing for $PMOS_USER" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/etc/environment.d/50-perry-wlr.conf \
  || { echo "ERROR: WLR env drop-in missing" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/lib/firmware/qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin \
  || { echo "ERROR: WCNSS NV missing" >&2; exit 1; }
sudo test -f /mnt/pmos-b-root/usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf \
  || { echo "ERROR: perry UCM missing" >&2; exit 1; }
# P1.5 — default ABSENT (hang root cause); optional ENABLE_P15 asserts present
if [[ "$ENABLE_P15" == "1" ]]; then
  sudo grep -q 'deviceinfo_framebuffer_wait_seconds' /mnt/pmos-b-root/usr/share/initramfs/init_functions.sh \
    || { echo "ERROR: ENABLE_P15=1 but initramfs missing framebuffer wait patch" >&2; exit 1; }
  echo "WARNING: image contains P1.5 — known hang on perry hardware"
else
  if sudo grep -q 'deviceinfo_framebuffer_wait_seconds' /mnt/pmos-b-root/usr/share/initramfs/init_functions.sh 2>/dev/null; then
    echo "ERROR: P1.5 patch present in initramfs (default build must not apply it)" >&2
    exit 1
  fi
  if sudo grep -q 'deviceinfo_framebuffer_wait_seconds' /mnt/pmos-b-root/usr/share/deviceinfo/deviceinfo 2>/dev/null; then
    echo "ERROR: deviceinfo still has framebuffer_wait_seconds" >&2
    exit 1
  fi
  echo "OK: P1.5 absent from initramfs + deviceinfo (boot-safe default)"
fi
# Kernel flavor: custom perry package, not generic msm89x7
if ! sudo grep -q motorola-perry /mnt/pmos-b-boot/extlinux/extlinux.conf \
  && ! sudo test -e /mnt/pmos-b-root/usr/share/kernel/motorola-perry/kernel.release; then
  echo "WARNING: could not confirm linux-motorola-perry flavor marker" >&2
fi
sudo cat /mnt/pmos-b-root/usr/share/kernel/motorola-perry/kernel.release 2>/dev/null \
  || sudo ls /mnt/pmos-b-root/usr/share/kernel/ 2>/dev/null || true

if sudo test -s /mnt/pmos-b-root/home/"$PMOS_USER"/.ssh/authorized_keys 2>/dev/null; then
  echo "ERROR: authorized_keys present" >&2
  exit 1
fi
if sudo find /mnt/pmos-b-root/etc/NetworkManager/system-connections \
     -type f -name '*.nmconnection' 2>/dev/null | grep -q .; then
  echo "ERROR: NetworkManager profiles present" >&2
  exit 1
fi

if [[ "$LEAN" != "1" ]]; then
  # Spot-check the stock Phosh recommend set (postmarketos-base-ui-gnome*).
  for app in \
    org.gnome.Calculator.desktop \
    org.gnome.Console.desktop \
    org.gnome.Calendar.desktop \
    firefox-esr.desktop \
    sm.puri.Chatty.desktop
  do
    sudo test -f /mnt/pmos-b-root/usr/share/applications/"$app" \
      || { echo "ERROR: full-apps build missing $app" >&2; exit 1; }
  done
  echo "OK: full-apps desktop entries present"
fi

cleanup_loop
trap - EXIT

if [[ "$LEAN" == "1" ]]; then
  APPS_NOTE="lean (\`--no-recommends\` — Settings/Software only from UI recommends)"
else
  APPS_NOTE="**full Phosh recommends** (Calculator, Calendar, Console, Firefox-ESR, Chatty, Calls, …)"
fi

cat > "$OUT_DIR/FLASH.md" <<EOF
# Phase B — motorola-perry + linux-motorola-perry (${DATE_UTC})
$([ -n "$BISECT_TAG" ] && echo "Variant: **${BISECT_TAG}**")
ENABLE_P15=${ENABLE_P15}
LEAN=${LEAN}

First-class \`device-motorola-perry\` / \`linux-motorola-perry\` Phosh image
with P0 userspace (zram via deviceinfo, \`WLR_DRM_NO_ATOMIC=1\`,
${APPS_NOTE}, USB nosuspend udev, service presets).

**P1.5:** default OFF (Bisect D: framebuffer-wait patch hung perry). Splash
gap may remain until a safe redesign.

Default login: **${PMOS_USER}** / **${PMOS_PASSWORD}**
SSH USB-net: \`${PMOS_USER}@172.16.42.1\` (host \`172.16.42.2/24\`,
\`nmcli device set <iface> managed no\`).

Sacred: never touch \`persist\` / \`modemst1\` / \`modemst2\`.

\`\`\`bash
# Prefer scripts/pmos-flash-phase-b-force.sh (chunked sparse + NORMAL≠FORCE asserts).
RAW=$OUT_DIR/${ROOTFS_NAME} SPARSE=$OUT_DIR/${SPARSE_NAME} \\
  ./scripts/pmos-flash-phase-b-force.sh
# Manual path (lk2nd fastboot, product: lk2nd-msm8952):
fastboot flash -S 100M userdata ${SPARSE_NAME}
fastboot flash boot ${LK2ND_NAME}   # must NOT contain force-fastboot string
fastboot continue
\`\`\`

Build: \`LEAN=${LEAN} ENABLE_P15=${ENABLE_P15} scripts/pmos-build-phase-b.sh\`
EOF

(
  cd "$OUT_DIR"
  sha256sum "$LK2ND_NAME" "$ROOTFS_NAME" "$SPARSE_NAME" > SHA256SUMS
)

echo
echo "OK. Phase B artifacts in $OUT_DIR"
ls -lh "$OUT_DIR"
echo "Flash with scripts/pmos-flash-phase-b-force.sh — then measure baselines."
