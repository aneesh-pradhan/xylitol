#!/usr/bin/env bash
# Install perry's ALSA UCM audio profile into a RUNNING postmarketOS rootfs.
#
# WHY: card "motorola-perry" comes up with no matching UCM (alsaucm -> -2,
# speaker-test "no backend DAIs") because pmaports/alsa-ucm-conf ships
# montana/hannah/potter but not perry. This drops
#   /usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf
# (reuses the shipped potter HiFi verb + msm8953-wcd codec sequences; every
# referenced control verified present on perry's msm8x16-wcd codec). It then
# enables user linger and restarts wireplumber so audio comes up immediately.
#
# SCOPE: survives a device reboot (written to the rootfs, synced to eMMC) but
# NOT `pmbootstrap install` (rootfs regen). For install-survival use the
# pmaport: scripts/pmos-apply-perry-ucm.sh.
#
# Safe: touches only /usr/share/alsa and user-service state.
# Never flashes, never touches persist/modemst*. Needs USB-net + SSH.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/alsa-ucm-motorola-perry"

DEVICE_IP="${DEVICE_IP:-172.16.42.1}"
DEVICE_USER="${DEVICE_USER:-xylitol}"
PMOS_SUDO_PW="${PMOS_SUDO_PW:-xylitol}"    # public-image default; change after first boot

UCM_SRC="$APORT_SRC/motorola-perry.conf"
UCM_DEST="/usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf"
# Legacy (pre-camera) drop-in — remove if still present so Snapshot works.
WP_LEGACY="/etc/wireplumber/wireplumber.conf.d/50-perry-disable-libcamera.conf"

[[ -f "$UCM_SRC" ]] || { echo "ERROR: missing $UCM_SRC" >&2; exit 1; }

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8)
SSH=(ssh "${SSH_OPTS[@]}" "${DEVICE_USER}@${DEVICE_IP}")

echo "Device    : ${DEVICE_USER}@${DEVICE_IP}"
if ! timeout 12 "${SSH[@]}" true 2>/dev/null; then
  echo "ERROR: cannot SSH to the device. Bring up USB-net first (see docs/handoff.md)." >&2
  exit 1
fi

echo "Copying UCM profile ..."
timeout 20 scp "${SSH_OPTS[@]}" "$UCM_SRC" "${DEVICE_USER}@${DEVICE_IP}:/tmp/" >/dev/null

timeout 40 "${SSH[@]}" "sh -s" <<EOF
set -e
printf '%s\n' "$PMOS_SUDO_PW" | sudo -S sh -c '
  install -Dm644 /tmp/motorola-perry.conf "$UCM_DEST"
  rm -f "$WP_LEGACY"
  loginctl enable-linger "$DEVICE_USER"
'
rm -f /tmp/motorola-perry.conf
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=\$XDG_RUNTIME_DIR/bus"
systemctl --user reset-failed wireplumber 2>/dev/null || true
systemctl --user restart wireplumber 2>/dev/null || true
sleep 3
echo "--- wireplumber: \$(systemctl --user is-active wireplumber) ---"
alsaucm -c motorola-perry list _verbs 2>&1 | head -2
wpctl status 2>/dev/null | sed -n '/Video/,/Settings/p' | head -40
EOF

echo
echo "OK. Video Sources should list ov5695/s5k4h8 [libcamera] once cameras are up."
echo "Make UCM install-durable with scripts/pmos-apply-perry-ucm.sh."
