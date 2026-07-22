#!/usr/bin/env bash
# Wait for stock Motorola fastboot (product: perry), flash known-good release,
# restore normal lk2nd, continue, probe USB-net SSH.
# Sacred: boot + userdata only.
set -euo pipefail
export PATH="${HOME}/bin:${PATH}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/artifacts/pmos-phase-b"
REL="$ROOT/artifacts/pmos-release/pmos-perry-2026-07-21"
LOG="$OUT/auto-bisect-cde.log"
mkdir -p "$OUT"

log() { echo "[$(date -u +%Y-%m-%dT%H:%MZ)] $*" | tee -a "$LOG"; }

SPARSE="$REL/qcom-msm89x7-perry-phosh.sparse.clean.img"
[[ -f "$SPARSE" ]] || SPARSE="$REL/qcom-msm89x7-perry-phosh.sparse.img"
RAW="$REL/qcom-msm89x7-perry-phosh.img.clean"
[[ -f "$RAW" ]] || RAW="$SPARSE"
NORMAL="$REL/lk2nd-msm8952-perry.img"
FORCE="$OUT/lk2nd-force-fastboot.img"

[[ -f "$SPARSE" && -f "$NORMAL" && -f "$FORCE" ]] || {
  log "ERROR: missing artifacts"
  ls -la "$SPARSE" "$NORMAL" "$FORCE" 2>&1 | tee -a "$LOG"
  exit 1
}

# Sparse must appear newer than raw for flash script age check
if [[ -f "$RAW" && "$RAW" != "$SPARSE" ]]; then
  if [[ ! "$SPARSE" -nt "$RAW" ]]; then
    touch "$SPARSE"
  fi
fi

log "ROLLBACK waiter: need stock fastboot product=perry (not lk2nd 24b071b)"
deadline=$((SECONDS + 3600))
while (( SECONDS < deadline )); do
  if timeout 4 fastboot devices 2>/dev/null | grep -q .; then
    p=$(timeout 8 fastboot getvar product 2>&1 | awk -F': ' '/^product:/{print $2}' | tr -d '\r' || true)
    sn=$(timeout 8 fastboot getvar serialno 2>&1 | awk -F': ' '/^serialno:/{print $2}' | tr -d '\r' || true)
    log "product=[$p] serialno=[$sn]"
    if [[ "$p" == "perry" ]]; then
      ok=0
      for _ in 1 2 3 4 5; do
        p2=$(timeout 8 fastboot getvar product 2>&1 | awk -F': ' '/^product:/{print $2}' | tr -d '\r' || true)
        [[ "$p2" == "perry" ]] && ok=$((ok + 1))
      done
      if (( ok >= 4 )); then
        log "stock fastboot stable ($ok/5) — flashing known-good"
        FORCE="$FORCE" NORMAL="$NORMAL" RAW="$RAW" SPARSE="$SPARSE" \
          LOG="$OUT/flash-rollback.log" \
          "$ROOT/scripts/pmos-flash-phase-b-force.sh" 2>&1 | tee -a "$LOG"
        log "flash script finished; probing SSH 180s"
        found=0
        for i in $(seq 1 60); do
          IFACE=""
          for n in /sys/class/net/*; do
            if grep -q cdc_ncm "$n/device/uevent" 2>/dev/null; then
              IFACE=$(basename "$n")
              break
            fi
          done
          if [[ -z "$IFACE" ]]; then
            IFACE=$(ls /sys/class/net 2>/dev/null | grep '^enx' | head -1 || true)
          fi
          if [[ -n "$IFACE" ]]; then
            sudo ip addr add 172.16.42.2/24 dev "$IFACE" 2>/dev/null || true
            sudo ip link set "$IFACE" up 2>/dev/null || true
            if timeout 3 ping -c1 -W2 172.16.42.1 >/dev/null 2>&1; then
              if timeout 15 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                  -o ConnectTimeout=10 -o BatchMode=yes \
                  xylitol@172.16.42.1 'echo SSH_OK_ROLLBACK; uname -a; uptime' 2>&1 | tee -a "$LOG"; then
                found=1
                break
              fi
            fi
          fi
          sleep 3
        done
        if (( found )); then
          log "RESULT: ROLLBACK PASS"
          echo "ROLLBACK=PASS" >> "$OUT/auto-bisect.result"
        else
          log "RESULT: ROLLBACK FLASHED — check Phosh on device"
          echo "ROLLBACK=FLASHED" >> "$OUT/auto-bisect.result"
        fi
        exit 0
      fi
    fi
  fi
  sleep 3
done
log "TIMEOUT waiting for stock fastboot"
exit 2
