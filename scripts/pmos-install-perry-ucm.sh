#!/usr/bin/env bash
# Install perry's ALSA UCM audio profile into a RUNNING postmarketOS rootfs.
#
# WHY: card "motorola-perry" comes up with no matching UCM (alsaucm -> -2,
# speaker-test "no backend DAIs") because pmaports/alsa-ucm-conf ships
# montana/hannah/potter but not perry. This drops
#   /usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf
# (reuses the shipped potter HiFi verb + msm8953-wcd codec sequences; every
# referenced control verified present on perry's msm8x16-wcd codec), plus a
# WirePlumber drop-in disabling the crash-looping libcamera monitor. It then
# enables user linger and restarts wireplumber so audio comes up immediately.
#
# SCOPE: survives a device reboot (written to the rootfs, synced to eMMC) but
# NOT `pmbootstrap install` (rootfs regen). For install-survival use the
# pmaport: scripts/pmos-apply-perry-ucm.sh.
#
# Safe: touches only /usr/share/alsa, /etc/wireplumber and user-service state.
# Never flashes, never touches persist/modemst*. Needs USB-net + SSH key auth.
set -euo pipefail

XYLITOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APORT_SRC="$XYLITOL_ROOT/pmos/alsa-ucm-motorola-perry"

DEVICE_IP="${DEVICE_IP:-172.16.42.1}"
DEVICE_USER="${DEVICE_USER:-aneesh}"
PMOS_SUDO_PW="${PMOS_SUDO_PW:-147147}"     # throwaway sudo pw; SSH is key-based

UCM_SRC="$APORT_SRC/motorola-perry.conf"
WP_SRC="$APORT_SRC/50-perry-disable-libcamera.conf"
UCM_DEST="/usr/share/alsa/ucm2/conf.d/motorola-perry/motorola-perry.conf"
WP_DEST="/etc/wireplumber/wireplumber.conf.d/50-perry-disable-libcamera.conf"

for f in "$UCM_SRC" "$WP_SRC"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8)
SSH=(ssh "${SSH_OPTS[@]}" "${DEVICE_USER}@${DEVICE_IP}")

echo "Device    : ${DEVICE_USER}@${DEVICE_IP}"
if ! timeout 12 "${SSH[@]}" true 2>/dev/null; then
  echo "ERROR: cannot SSH to the device. Bring up USB-net first (see docs/handoff.md E-10)." >&2
  exit 1
fi

# Ship both configs to a tmp dir, then sudo-move into place.
echo "Copying UCM profile + WirePlumber drop-in ..."
timeout 20 scp "${SSH_OPTS[@]}" "$UCM_SRC" "$WP_SRC" "${DEVICE_USER}@${DEVICE_IP}:/tmp/" >/dev/null

timeout 40 "${SSH[@]}" "sh -s" <<EOF
set -e
printf '%s\n' "$PMOS_SUDO_PW" | sudo -S sh -c '
  install -Dm644 /tmp/motorola-perry.conf "$UCM_DEST"
  install -Dm644 /tmp/50-perry-disable-libcamera.conf "$WP_DEST"
  loginctl enable-linger "$DEVICE_USER"
'
rm -f /tmp/motorola-perry.conf /tmp/50-perry-disable-libcamera.conf
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=\$XDG_RUNTIME_DIR/bus"
systemctl --user reset-failed wireplumber 2>/dev/null || true
systemctl --user restart wireplumber 2>/dev/null || true
sleep 3
echo "--- wireplumber: \$(systemctl --user is-active wireplumber) ---"
alsaucm -c motorola-perry list _verbs 2>&1 | head -2
wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | head -6
EOF

echo
echo "OK. If a sink 'Speaker playback' + source 'Primary Microphone' appear,"
echo "audio is up. Make it install-durable with scripts/pmos-apply-perry-ucm.sh."
