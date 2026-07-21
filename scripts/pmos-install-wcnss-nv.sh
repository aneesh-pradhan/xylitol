#!/usr/bin/env bash
# Install perry's WCNSS WiFi NV blob into a running postmarketOS rootfs.
#
# WHY: our perry DTS (pmos/linux-postmarketos-qcom-msm89x7/0003-*.patch) sets
#   &wcnss_ctrl { firmware-name = "qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin"; }
# The pmOS rootfs ships NV blobs for sibling MSM8937 Motos (cedric, montana)
# but NOT perry, so wcn36xx fails the NV load with -2 (ENOENT) and never
# creates wlan0. Dropping perry's own NV at that path fixes WiFi end-to-end
# (verified 2026-07-20: wlan0 up, associates + DHCP, clean cold boot, no -2).
#
# The NV blob is a proprietary Motorola vendor file — it is NOT committed to
# this repo (.gitignore blocks *.bin). This script copies it from a LOCAL
# source into the device over SSH.
#
# SCOPE: this survives a device reboot (written to the rootfs, synced to eMMC)
# but does NOT survive `pmbootstrap install` (rootfs regen). For install-
# survival, promote it to a local pmaport — see docs/pmos-runbook.md.
#
# Safe: touches only /lib/firmware on the device. Never flashes, never touches
# persist/modemst*. Requires the device reachable over USB-net + SSH key auth.
set -euo pipefail

DEVICE_IP="${DEVICE_IP:-172.16.42.1}"
DEVICE_USER="${DEVICE_USER:-xylitol}"
# Public-image default password (override via env; change after first boot).
PMOS_SUDO_PW="${PMOS_SUDO_PW:-xylitol}"

DEST="/lib/firmware/qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin"
EXPECT_MD5="4f88c4c5435d0d80c5e1c9bbe360a57e"   # perry vendor NV (NCQS26.69-64-21)

# Locate the NV blob locally: prefer the stable backup copy, fall back to the
# Lineage build output (out/ gets wiped on clean builds — hence the backup).
SRC=""
for cand in \
  "$HOME/android/backups/perry/WCNSS_qcom_wlan_nv.perry.bin" \
  "$HOME/android/lineage/out/target/product/perry/vendor/etc/wifi/WCNSS_qcom_wlan_nv.bin" \
  "${WCNSS_NV_SRC:-}" ; do
  if [[ -n "$cand" && -f "$cand" ]]; then SRC="$cand"; break; fi
done
if [[ -z "$SRC" ]]; then
  echo "ERROR: perry WCNSS NV not found locally." >&2
  echo "  Looked in ~/android/backups/perry/ and the Lineage build output." >&2
  echo "  Set WCNSS_NV_SRC=/path/to/WCNSS_qcom_wlan_nv.bin and retry." >&2
  exit 1
fi

echo "Source NV : $SRC"
LOCAL_MD5="$(md5sum "$SRC" | cut -d' ' -f1)"
echo "Local md5 : $LOCAL_MD5"
if [[ "$LOCAL_MD5" != "$EXPECT_MD5" ]]; then
  echo "WARNING: local md5 != known perry NV ($EXPECT_MD5)." >&2
  echo "         Continuing anyway (set a different blob deliberately?)." >&2
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8)
SSH=(ssh "${SSH_OPTS[@]}" "${DEVICE_USER}@${DEVICE_IP}")

echo "Device    : ${DEVICE_USER}@${DEVICE_IP}"
if ! timeout 12 "${SSH[@]}" true 2>/dev/null; then
  echo "ERROR: cannot SSH to the device. Bring up USB-net first, e.g.:" >&2
  echo "  sudo ip addr add 172.16.42.2/24 dev <usb-iface>; ping 172.16.42.1" >&2
  exit 1
fi

# Step 1: stream the blob to /tmp (no sudo -> no stdin collision with sudo -S).
timeout 30 "${SSH[@]}" "cat > /tmp/perry_wcnss_nv.bin" < "$SRC"

# Step 2: sudo-place it (password via its own pipe; cp reads no stdin), verify.
REMOTE_MD5="$(timeout 30 "${SSH[@]}" "
  printf '%s\n' '${PMOS_SUDO_PW}' | sudo -S -p '' sh -c '
    mkdir -p \"\$(dirname \"$DEST\")\"
    cp /tmp/perry_wcnss_nv.bin \"$DEST\"
    sync
    rm -f /tmp/perry_wcnss_nv.bin
  '
  md5sum \"$DEST\" | cut -d\" \" -f1
" 2>/dev/null | tail -1)"

echo "Remote md5: $REMOTE_MD5"
if [[ "$REMOTE_MD5" != "$LOCAL_MD5" ]]; then
  echo "ERROR: md5 mismatch after copy (remote=$REMOTE_MD5 local=$LOCAL_MD5)." >&2
  exit 1
fi

echo "OK: installed perry WCNSS NV at $DEST"
echo
echo "To activate WiFi now, reboot the device (a clean cold boot loads the NV"
echo "and wcn36xx creates wlan0). Manual remoteproc restart can wedge the"
echo "WCNSS SMD channel — prefer a reboot:"
echo "  ${SSH[*]} \"printf '%s\\\\n' '${PMOS_SUDO_PW}' | sudo -S sh -c 'sync; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger'\""
