# Session handoff — perry / xylitol

**Date:** 2026-07-19  
**Meta-repo tip:** `00124df` on `main` (synced with `origin/main`)  
**Lineage tree:** `~/android/lineage` (not in this repo)  
**Build host:** Ubuntu 26.04 LTS (`resolute`), passwordless sudo available

This document is the pick-up point for the next session. Detailed chronology lives in
[`porting-log.md`](porting-log.md); project rules and device facts live in
[`../CLAUDE.md`](../CLAUDE.md).

---

## 1. Project phase (where we are)

| Phase | Status |
|---|---|
| Evidence / ceiling (LOS 18.1, not 19+) | **Done** |
| Local manifest + sync scripts | **Done** |
| First perry device-tree 17.1→18.1 patches | **Done** (applied in tree) |
| Environment setup + full `repo sync` | **Done** |
| First `brunch` / `m bacon` attempts | **In progress** — full bacon running; no flashable zip yet |
| XT1765-accurate proprietary list + extract | **Not done** (partial / montana-contaminated) |
| Boot + SELinux denial loop | **Not started** |
| Daily-driver polish | **Not started** |

**One-line summary:** We are in **first successful full build** territory. Platform
port scaffolding and several Soong/kernel blockers are fixed and committed as
patches. A full `m bacon` is running after the OMX/V4L2 fix; it has not produced
a ROM zip yet. Blob extraction quality is the largest known content gap that
will bite runtime even if the build finishes.

**Goal remains:** LineageOS **18.1 (Android 11)** for XT1765 perry — evidence-backed
ceiling for moto-msm89xx. Do not pivot to 19.0+ without new evidence.

---

## 2. Current machine state

### Meta-repo (`~/GitHub/xylitol`)

- Working tree **clean**; `main` == `origin/main` at `00124df`.
- Cursor co-author trailer removed from history (force-pushed earlier this session).
- Eight patches under `patches/` (see §4).
- Scripts: `setup-env.sh`, `sync.sh`, `apply-patches.sh`, `extract-perry.sh`.

### Lineage tree (`~/android/lineage`)

| Project | Manifest pin | Local tip (patches applied) | Notes |
|---|---|---|---|
| `device/motorola/perry` | lineage-17.1 | includes 0001–0005 | Detached HEAD, clean |
| `device/motorola/msm8937-common` | lineage-18.1 | includes Android.mk perry filter | Detached HEAD, clean |
| `kernel/motorola/msm8953` | lineage-18.1 | recovery defconfig + V4L2 uapi | Detached HEAD, clean |
| `vendor/motorola` | lineage-18.1 | upstream `ec513e1` | Untracked `perry/` from local extract |

Patches are **already applied** in the live tree. Do **not** re-run
`apply-patches.sh` unless those repos are reset to clean upstream tips.

### Build in flight (as of handoff write-up)

- Command: `m bacon` / lunch `lineage_perry-userdebug`
- Log: `~/android/lineage/logs/brunch-perry-20260719-154117.log`
- Progress snapshot: early ninja (~3% of ~105k); **no FAILED** yet at last check
- Artifacts: **no** `lineage-*.zip` / boot.img under `out/target/product/perry/` yet
- Prior full attempt (`…-145405.log`) failed ~40% on OMX V4L2; that issue is patched
- Targeted OMX rebuild (`…-153635.log`) **succeeded** after the uapi shim

**First action next session:** check whether `154117` finished:

```bash
tail -80 ~/android/lineage/logs/brunch-perry-20260719-154117.log
ls -lh ~/android/lineage/out/target/product/perry/*.zip 2>/dev/null
pgrep -af 'ninja|soong_ui|bacon' | head
```

---

## 3. What was accomplished this session

1. Confirmed Ubuntu **26.04** build host; retargeted `setup-env.sh`.
2. Fixed `clone-depth="0"` rejection (modern repo); sync now unshallows the four
   perry-related projects after shallow AOSP sync. Fixed illegal `--` inside XML
   comments.
3. Synced lineage-18.1 tree; applied perry + kernel patches.
4. Hit and fixed extract footgun: bare `extract-files.sh` with `CLEAN_VENDOR=true`
   wiped `msm8937-common/proprietary/`. Restored from git. Added
   `scripts/extract-perry.sh` and README warning.
5. Build blockers fixed and patched into xylitol:
   - **dtbtool** → Soong (`perry/0004`)
   - **msm8937-common `Android.mk`** device filter missing `perry` (`msm8937-common/0001`)
   - **`perry_recovery_defconfig`** missing → WLAN-stripped twin of `perry_defconfig`
     (`kernel/0001`)
   - **OMX V4L2 uapi** gap: common sets `TARGET_KERNEL_VERSION := 4.9` but kernel
     uapi is still 3.18-style → aliases for `V4L2_QCOM_CMD_FLUSH` /
     `V4L2_MPEG_VIDEO_H264_LEVEL_UNKNOWN` (`kernel/0002`)
6. Partial XT1765 extract: **26** blobs on disk; `perry-vendor.mk` regenerated
   locally to match present files only (`perry/0005` hardens extract for partial sets).

---

## 4. Patch inventory (apply order by directory)

### `patches/device/motorola/perry/`

| Patch | Purpose |
|---|---|
| `0001` | Treble vendor sepolicy dirs, `TARGET_KERNEL_RECOVERY_CONFIG`, `include` vendor BoardConfig |
| `0002` | `DEVICE_COMMON` → `BOARD_COMMON` for msm8937-common extract contract |
| `0003` | `sepolicy/` → `sepolicy/vendor/` |
| `0004` | Convert `dtbTool_custom` from obsolete `BUILD_HOST_EXECUTABLE` to Soong |
| `0005` | Harden extract-files for partial XT1765 blob sets |

### `patches/device/motorola/msm8937-common/`

| Patch | Purpose |
|---|---|
| `0001` | Add `perry` to `Android.mk` filter so `librecovery_updater_motorola` builds |

### `patches/kernel/motorola/msm8953/`

| Patch | Purpose |
|---|---|
| `0001` | Add `arch/arm64/configs/perry_recovery_defconfig` (WLAN stripped) |
| `0002` | UAPI aliases for CAF msm8996 media when `TARGET_KERNEL_VERSION=4.9` |

---

## 5. Errors / gaps still open

### A. Full bacon not proven green (highest urgency)

The post-V4L2 full build may still fail on the next missing symbol, makefile, or
blob path. Until a zip exists under `out/target/product/perry/`, treat “build
works” as **unproven**.

### B. `proprietary-files.txt` is montana-contaminated (highest content risk)

Upstream perry list is largely **montana 8.1** leftovers. Device in hand is
stock Nougat **`NPNS26.118-22-1`** (`motorola/perry/perry`), not montana.

Observed mismatches (non-exhaustive):

| List expects | XT1765 reality (approx.) |
|---|---|
| `l5695f60` chromatix naming | `l5695fa0` / ov5695 on device |
| Full `s5k3p3` / `s5k3p8sp` chromatix blocks | Partial; no s5k3p8 chromatix pulled |
| FPC fingerprint `@2.1-fpcservice` | Egis-style stack; no FPC HAL paths from probes |
| `libpn553_fw` / montana touch `*-montana.tdat` | `libpn548ad_fw`; no montana tdat |
| Many `lib64` sensor paths | 32-bit userspace; prefer `lib/` |
| 99 listed entries | **26** files actually extracted |

`device.mk` still references camera XML names that may not match stock. Runtime
camera / FP / NFC / display calibration will be wrong even if Soong succeeds.

**Note:** `CLAUDE.md` records stock build `NCQS26.69-64-21` from earlier
fastboot work; the connected phone reported `NPNS26.118-22-1`. Reconcile which
build is the blob base before rewriting the proprietary list.

### C. Common vendor depends on git blobs, not this phone

`msm8937-common/proprietary-files.txt` targets a newer layout (e.g. deen_sprout /
`system_ext`). Do **not** re-extract common from XT1765 Nougat. Keep restoring
from `vendor/motorola` git if wiped.

### D. Not started (expected after first boot)

- Device-level HAL / compatibility matrix diffs vs cedric (if any beyond common)
- SELinux denial harvest (`adb logcat`, `dmesg`, `audit2allow`) and sepolicy patches
- Shim work for remaining Nougat blobs (`libshims` already present in tree)
- Recovery/kernel `depmod` warnings seen around prior ninja failure (secondary)
- Flashing procedure with squid2 TWRP; **never** wipe `persist` / `modemst1` /
  `modemst2`

### E. Meta / docs drift

- `README.md` is still thin (blob warning only) — this handoff is the narrative.
- `CLAUDE.md` still mentions Ubuntu 24.04 in places; host is **26.04**. Update when
  convenient.

---

## 6. Research agenda for next session

Prioritize in this order unless the bacon log shows a new hard failure.

### 1. Triage the current / latest bacon log

- If **failed:** capture first `FAILED:` target, classify (kernel / CAF HAL /
  missing blob / Soong / sepolicy compile), fix with a xylitol patch, rebuild
  with `m bacon` (avoid wiping `out/` unless necessary; `m installclean` for
  config churn).
- If **succeeded:** locate zip, back it up off-tree, document hash/size in
  porting-log. Do **not** flash until proprietary rewrite plan is clear (or
  accept a “build smoke only” boot with known broken camera/FP).

### 2. Rewrite `proprietary-files.txt` for XT1765

Research method:

1. Boot stock (or known-good Nougat) with `adb root` / debuggable as needed.
2. Inventory real paths:
   - `adb shell find /vendor /system -name 'libmmcamera*' -o -name 'libchromatix*' …`
   - Fingerprint: `*egis*`, `*fingerprint*`, `uinput-egis*`
   - NFC firmware, synaptics firmware, qdcm / display calibration
3. Diff against current `proprietary-files.txt` and against
   `vendor/motorola/perry/proprietary/` (26 files).
4. Produce a new list (and xylitol patch). Prefer paths that exist on **this**
   device’s stock build; drop montana-only blocks.
5. Re-extract with `./scripts/extract-perry.sh adb` only (never wipe common).
6. Align `device.mk` `PRODUCT_COPY_FILES` camera XML names with what extract
   actually produced / what stock ships.

Reference siblings for *shape* of 17.1→18.1 extract scripts (cedric/hannah), not
for perry blob *names*.

### 3. Understand `TARGET_KERNEL_VERSION := 4.9` vs 3.18 reality

We shimmed two V4L2 macros. Research whether more 4.9-gated CAF media / display /
audio codepaths will fail the same way. Options to research (do not change
blindly):

- Additional uapi backports vs staging msm8953
- Whether siblings carry local media headers
- Cost of leaving `TARGET_KERNEL_VERSION=4.9` vs forcing the 3.18 media path in
  common (likely worse — common’s 18.1 stack assumes 4.9)

### 4. Arch / ABI clarity for docs

`msm8937-common` on 18.1: `TARGET_ARCH := arm64` + `TARGET_2ND_ARCH := arm`.
Kernel defconfigs live under `arch/arm64/configs/`. Userspace vendor blobs remain
32-bit Nougat. Document this carefully so future sessions do not “fix” arm64
blob paths.

### 5. After first bootable image

- `fastboot boot twrp.img` (prefer boot over flash until stable)
- Collect boot logcat + `last_kmsg`
- SELinux: permissive first if needed, then denials → `sepolicy/vendor` patches
- Log every fix in `docs/porting-log.md` with date

---

## 7. Resume checklist (copy-paste)

```bash
# 0. OS sanity
. /etc/os-release; echo "$PRETTY_NAME"   # expect Ubuntu 26.04

# 1. Build status
tail -80 ~/android/lineage/logs/brunch-perry-20260719-154117.log
ls -lh ~/android/lineage/out/target/product/perry/*.zip 2>/dev/null

# 2. If need a fresh build after fixes
cd ~/android/lineage
source build/envsetup.sh
lunch lineage_perry-userdebug
m bacon -j$(nproc) 2>&1 | tee logs/brunch-perry-$(date +%Y%m%d-%H%M%S).log

# 3. If repos were reset, re-apply patches once
bash ~/GitHub/xylitol/scripts/apply-patches.sh

# 4. Perry-only blob refresh (device booted to *system*, not TWRP/fastboot)
bash ~/GitHub/xylitol/scripts/extract-perry.sh adb

# 5. If common proprietary was wiped
cd ~/android/lineage/vendor/motorola
git checkout HEAD -- msm8937-common/proprietary/
```

### Device mode cheat sheet

| Task | Mode |
|---|---|
| `extract-perry.sh` / `extract-files.sh` | **System** (`adb get-state` → `device`) |
| `apply-patches` / `brunch` / `m bacon` | Host only |
| Flash / `fastboot boot twrp` | Fastboot |
| Do not extract from TWRP | Recovery reports `recovery`; extract-utils rejects it |

---

## 8. Sacred / do-not-touch

- Never wipe or repartition `persist`, `modemst1`, `modemst2` (EFS/IMEI). Off-device
  TWRP backups exist — treat them as sacred.
- Never commit Lineage tree, `out/`, ccache, or proprietary blobs into xylitol.
- Prefer `fastboot boot twrp.img` over flashing recovery until the ROM is stable.
- Do not add Cursor/Claude co-author trailers on commits pushed to GitHub.

---

## 9. Suggested first messages for the next agent/session

1. “Read `docs/handoff.md` and `docs/porting-log.md`. Check whether
   `brunch-perry-20260719-154117` finished and report zip or next FAILED.”
2. If green: “Inventory XT1765 stock blobs over adb and draft a replacement
   `proprietary-files.txt` patch.”
3. If red: “Fix the failure as a xylitol patch, apply to the live tree, resume
   `m bacon` without wiping `out/`.”
