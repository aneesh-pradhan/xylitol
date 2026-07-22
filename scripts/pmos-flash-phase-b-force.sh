#!/usr/bin/env bash
# Clean Phase B flash: stock → force-fastboot lk2nd → sparse userdata → normal lk2nd → continue
# Do NOT interrupt mid-write. Final chunks can take several minutes on eMMC.
# Sacred: never touches persist / modemst1 / modemst2.
#
# Env overrides (for bisect images without editing this script):
#   RAW=.../motorola-perry-phosh-bisectA.img \
#   SPARSE=.../motorola-perry-phosh-bisectA.sparse.img \
#     ./scripts/pmos-flash-phase-b-force.sh
# Optional: FORCE= NORMAL= OUT= LOG=
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/artifacts/pmos-phase-b}"
FORCE="${FORCE:-$OUT/lk2nd-force-fastboot.img}"
NORMAL="${NORMAL:-$OUT/lk2nd-msm8952-perry.img}"
RAW="${RAW:-$OUT/motorola-perry-phosh.img}"
SPARSE="${SPARSE:-$OUT/motorola-perry-phosh.sparse.img}"
LOG="${LOG:-$OUT/flash.log}"

echo "==> flash artifacts:"
echo "    FORCE  = $FORCE"
echo "    NORMAL = $NORMAL"
echo "    RAW    = $RAW"
echo "    SPARSE = $SPARSE"

[[ -f "$FORCE" && -f "$NORMAL" && -f "$SPARSE" ]] || {
  echo "Missing artifacts (need FORCE, NORMAL, SPARSE)" >&2
  exit 1
}

# NORMAL must never be a FORCE-FASTBOOT binary (poisoned package cache class of bug).
# Use grep -a on the file directly — NOT `strings | grep -q` under pipefail
# (grep -q closes the pipe early → strings SIGPIPE → false negative).
MARKER='Fastboot mode was forced with compile-time flag.'
if grep -aFq "$MARKER" "$NORMAL"; then
  echo "ERROR: $NORMAL is FORCE-FASTBOOT — refusing to flash as NORMAL" >&2
  exit 1
fi
if ! grep -aFq "$MARKER" "$FORCE"; then
  echo "ERROR: $FORCE lacks force-fastboot marker — refusing to use as FORCE" >&2
  exit 1
fi

# Sparse must be newer than raw when raw exists (stale-sparse gotcha).
if [[ -f "$RAW" ]]; then
  if [[ ! "$SPARSE" -nt "$RAW" ]]; then
    echo "ERROR: $SPARSE is not newer than $RAW — regenerate with img2simg" >&2
    exit 1
  fi
fi

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
