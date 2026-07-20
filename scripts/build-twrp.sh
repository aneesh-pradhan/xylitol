#!/usr/bin/env bash
# Build official TWRP recoveryimage for perry (Omni 7.1 / TeamWin tree).
#
# Host notes (Ubuntu 26.04):
# - Needs OpenJDK 8
# - Needs Python 2.7 on PATH as `python` (micromamba env py27)
# - Unset Lineage TOP before lunch; Omni envsetup breaks under `set -u`
set -eo pipefail

TWRP_DIR="${TWRP_DIR:-$HOME/android/twrp}"
OUT_COPY="${OUT_COPY:-$HOME/android/recovery}"
JOBS="${JOBS:-$(nproc)}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}"
PY27_BIN="${PY27_BIN:-$HOME/android/mamba/envs/py27/bin}"

if [[ ! -x "$PY27_BIN/python" ]]; then
  echo "Python 2.7 not found at $PY27_BIN/python" >&2
  echo "Create with: micromamba create -y -n py27 -c conda-forge python=2.7" >&2
  exit 1
fi
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "JDK 8 not found at $JAVA_HOME" >&2
  exit 1
fi
if [[ ! -f "$TWRP_DIR/build/envsetup.sh" ]]; then
  echo "TWRP tree missing at $TWRP_DIR — run scripts/sync-twrp.sh first" >&2
  exit 1
fi

mkdir -p "$TWRP_DIR/logs" "$OUT_COPY"
LOG="$TWRP_DIR/logs/recoveryimage-$(date +%Y%m%d-%H%M%S).log"
IMG="$TWRP_DIR/out/target/product/perry/recovery.img"

echo "==> python: $($PY27_BIN/python --version 2>&1)"
echo "==> java:   $($JAVA_HOME/bin/java -version 2>&1 | head -1)"
echo "==> log:    $LOG"

# Run envsetup/lunch/make in a fresh bash so Omni's shell pollution
# cannot break this wrapper. LC_ALL=C: Omni's prebuilt flex-2.5.39 aborts
# on glibc 2.43+ locales (_nl_intern_locale_data assert).
env -u TOP -u ANDROID_BUILD_TOP -u ANDROID_PRODUCT_OUT -u OUT \
  -u TARGET_PRODUCT -u TARGET_BUILD_VARIANT -u TARGET_BUILD_TYPE \
  -u TARGET_BUILD_APPS \
  PATH="$PY27_BIN:$JAVA_HOME/bin:/usr/bin:/bin" \
  JAVA_HOME="$JAVA_HOME" \
  ALLOW_MISSING_DEPENDENCIES=true \
  TW_DEVICE_VERSION="${TW_DEVICE_VERSION:-0}" \
  LC_ALL=C \
  LANG=C \
  TWRP_DIR="$TWRP_DIR" \
  JOBS="$JOBS" \
  LOG="$LOG" \
  bash --noprofile --norc -c '
    set +u
    set -eo pipefail
    cd "$TWRP_DIR"
    source build/envsetup.sh
    lunch omni_perry-eng
    echo "==> command make recoveryimage -j$JOBS"
    # Bypass envsetup make() wrapper; call GNU make directly
    # Size assert may fail (img ~17.4MB vs partition 0x1019000=16.1MB) —
    # same as official dl.twrp.me perry image; still usable with fastboot boot.
    set +e
    command make recoveryimage -j"$JOBS" 2>&1 | tee "$LOG"
    make_rc=${PIPESTATUS[0]}
    set -e
    if [[ ! -f out/target/product/perry/recovery.img ]]; then
      exit "${make_rc:-1}"
    fi
    if [[ "$make_rc" -ne 0 ]]; then
      echo "WARNING: make exited $make_rc but recovery.img exists (likely size assert); continuing"
    fi
  '

if [[ ! -f "$IMG" ]]; then
  echo "ERROR: recovery.img not found at $IMG" >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$OUT_COPY/twrp-perry-local-$STAMP.img"
cp -f "$IMG" "$DEST"
cp -f "$IMG" "$OUT_COPY/twrp-perry-local-latest.img"
ls -lh "$IMG" "$DEST"
echo "==> fastboot boot (do not flash until verified):"
echo "  adb reboot bootloader"
echo "  fastboot boot $DEST"
