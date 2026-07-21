#!/usr/bin/env bash
# Clean Phase B flash: stock → force-fastboot lk2nd → sparse userdata → normal lk2nd → continue
# PARKED 2026-07-21 — do not run unless explicitly resuming device flash.
# Do NOT interrupt mid-write. Final chunks can take several minutes on eMMC.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/artifacts/pmos-phase-b"
FORCE="$OUT/lk2nd-force-fastboot.img"
NORMAL="$OUT/lk2nd-msm8952-perry.img"
SPARSE="$OUT/motorola-perry-phosh.sparse.img"
LOG="$OUT/flash.log"

[[ -f "$FORCE" && -f "$NORMAL" && -f "$SPARSE" ]] || {
  echo "Missing artifacts in $OUT" >&2
  exit 1
}

echo "==> Waiting for STOCK fastboot (product=perry) or clean lk2nd..."
P=""
while true; do
  if fastboot devices 2>/dev/null | grep -q .; then
    P=$(timeout 8 fastboot getvar product 2>&1 | awk -F': ' '/^product:/{print $2}' | tr -d '\r' || true)
    echo "product=$P"
    if [[ "$P" == "perry" ]] || echo "$P" | grep -qi lk2nd; then
      break
    fi
  fi
  sleep 1
done

if [[ "$P" == "perry" ]]; then
  echo "==> flash normal lk2nd to boot + boot FORCE-FASTBOOT (RAM)"
  fastboot flash boot "$NORMAL"
  fastboot boot "$FORCE"
  echo "==> waiting for lk2nd-msm8952..."
  for i in $(seq 1 60); do
    P=$(timeout 8 fastboot getvar product 2>&1 | awk -F': ' '/^product:/{print $2}' | tr -d '\r' || true)
    echo "t=$i product=$P"
    echo "$P" | grep -qi lk2nd && break
    sleep 1
  done
  echo "$P" | grep -qi lk2nd || { echo "failed to enter lk2nd" >&2; exit 1; }
fi

echo "==> flashing sparse userdata with -S 100M"
echo "    DO NOT INTERRUPT — can take 5–10 minutes on eMMC"
date -u +%H:%M:%SZ | tee -a "$LOG"
fastboot flash -S 100M userdata "$SPARSE" 2>&1 | tee -a "$LOG"
echo "==> restore normal lk2nd on boot"
fastboot flash boot "$NORMAL" 2>&1 | tee -a "$LOG"
echo "==> continue"
fastboot continue 2>&1 | tee -a "$LOG"
echo FLASH_COMPLETE
date -u +%H:%M:%SZ
