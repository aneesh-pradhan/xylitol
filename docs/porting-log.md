# Porting log

## 2026-07-19 — verified moto-msm89xx repo names/branches before writing manifests/perry.xml

Checked github.com/moto-msm89xx directly (API + raw file contents) rather than
trusting names from memory:

- `android_device_motorola_perry` — only branches are `lineage-16.0`,
  `lineage-17.1`, `lineage-18.0`, `dynamic/lineage-17.1`. **`lineage-18.0` is
  not a real perry port** — its `BoardConfig.mk` still points at
  `montana_defconfig` and `vendor/motorola/montana/BoardConfigVendor.mk`, and
  its last commit (2020-09-14) predates `lineage-17.1`'s last commit
  (2020-11-13). It's stale montana leftovers from whatever process bulk-created
  branches across the org. Porting base is `lineage-17.1`.
- No `msm8917-common` repo exists. perry's `lineage.dependencies` pulls
  `android_device_motorola_msm8937-common` → `device/motorola/msm8937-common`
  (`TARGET_BOARD_PLATFORM := msm8937` — LOS buckets the 8917/8937 family under
  one platform macro). This repo already has a real `lineage-18.1` branch.
- No `kernel_motorola_msm8917` repo exists. `msm8937-common`'s
  `BoardConfigCommon.mk` sets `TARGET_KERNEL_SOURCE := kernel/motorola/msm8953`
  (`android_kernel_motorola_msm8953`), built with `perry_defconfig`. This also
  already has a real `lineage-18.1` branch. Between this and msm8937-common,
  most of the platform-level 17.1→18.1 work already exists upstream; perry's
  own device tree (BoardConfig, sepolicy, HAL versions) is the actual gap.
- perry has no dedicated vendor repo. `BoardConfig.mk` inherits
  `vendor/motorola/montana/BoardConfigVendor.mk` from the shared
  `proprietary_vendor_motorola` repo (root dirs: `cedric/`, `hannah-common/`,
  `james/`, `montana/`, `msm8937-common/`). Manifest clones the whole repo to
  `vendor/motorola`, not `vendor/motorola/montana` — `montana/` is a subdir of
  it. This repo also has blobs on a `lineage-18.1` branch already.

See `manifests/perry.xml` for the local manifest. Initial draft pinned
all four projects to `lineage-17.1`; repinned to `lineage-18.1` for the
platform repos in the entry below once `git compare` confirmed those
branches are real. Full history for the four perry-related projects is
handled by `scripts/sync.sh` (unshallow after sync), not by
`clone-depth="0"` — current repo rejects that attribute.

## 2026-07-19 — fastboot re-verification, Android version ceiling, manifest revision-pinning fix

Device plugged in and in fastboot mode; `fastboot getvar all` matches every
field already recorded in CLAUDE.md's device table exactly (perry_tmo XT1765,
MSM8917, 2GB RAM, 16GB Samsung eMMC, 3.18.31 kernel, flashing_unlocked, hwrev
P3B) — no corrections needed there.

**Android version ceiling.** Ran `git compare lineage-17.1...lineage-18.1` (GitHub
API, `ahead_by`/`behind_by`) across every repo touching this device family to
find the real ceiling rather than guessing from the "11–13" range originally
written down:

| repo | ahead_by | behind_by | verdict |
|---|---|---|---|
| android_device_motorola_msm8937-common | 194 | 2 | real |
| android_kernel_motorola_msm8953 | 1463 | 1 | real |
| proprietary_vendor_motorola | 26 | 0 | real |
| android_device_motorola_jeter | 1 | 0 | real, but a device consolidation not a HAL bump (see below) |
| android_device_motorola_cedric | 31 | 0 | real |
| android_device_motorola_hannah | 2 | 0 | real |

No repo in the org has a branch past `lineage-18.1` that isn't stale:
- perry's `lineage-18.0` (see above) predates its own `lineage-17.1`.
- montana's `lineage-19.0`: checked the same way — `ahead_by 0, behind_by 6`
  against montana's own `lineage-18.1`, and its last commit is dated
  2017-11-03 (older than the 17.1 work). Also a stale/mislabeled branch, not
  a real Android 12 port.

Conclusion: **lineage-18.1 (Android 11) is the evidence-backed ceiling** for
this device family — not just for perry, for the whole org. Going to
Android 12+ would mean originating the VNDK/HAL bump from scratch with zero
prior art anywhere in moto-msm89xx, stacked on top of the existing hardware
ceiling (2GB RAM, 16GB storage, ARM32-only Nougat blobs, 3.18 ION kernel).
Updated CLAUDE.md's Goal section accordingly — 19.0+ is now framed as an
unproven stretch goal, not a default target.

**Manifest fix.** Since msm8937-common/kernel_msm8953/proprietary_vendor_motorola
all have *real* lineage-18.1 branches (confirmed above), pinning them to
lineage-17.1 in the original manifest meant redoing work that's already done
upstream. Repinned all three to `lineage-18.1` in `manifests/perry.xml`, kept
`android_device_motorola_perry` on `lineage-17.1` (its only real branch;
that's the actual porting target now that the platform layer underneath it is
already 18.1).

**Porting template.** Pulled the file lists for cedric's and hannah's real
`lineage-17.1...lineage-18.1` diffs to see what a perry port actually needs:
- cedric (31 commits): `BoardConfig.mk` changes, `sepolicy/` → `sepolicy/vendor/`
  restructure, `proprietary-files.txt` updates, `extract-files.sh`/
  `setup-makefiles.sh` aligned to newer extraction-utils templates, a new
  `board-info.txt`.
- hannah (2 commits): minimal case — `BoardConfig.mk` plus extraction-script
  template alignment and a recovery kernel defconfig line.
- jeter (1 commit) looked like the cleanest reference (fewest commits) but
  isn't: its "18.1" commit collapses jeter into inheriting hannah-common
  entirely (a device consolidation), not a HAL/VNDK bump. Not a usable
  template for perry.

**Next step:** run `scripts/setup-env.sh` + `scripts/sync.sh` on the build
host, then start applying cedric's diff shape to perry's own tree
(`BoardConfig.mk`, `sepolicy/vendor/` restructure, extraction-script
alignment), swapping in perry's own defconfig/blobs.

## 2026-07-19 — drafted and verified the first 3 perry device-tree patches

Didn't wait for a real sync: fetched perry's actual current `lineage-17.1`
files from GitHub directly, adapted cedric's real diff pattern to them
(not copy-pasted — checked each change against what perry's own files
actually contain first), and wrote the result to
`patches/device/motorola/perry/000{1,2,3}-*.patch`. Verified for real: cloned
`moto-msm89xx/android_device_motorola_perry` at `lineage-17.1` fresh into a
scratch dir and ran `git am patches/device/motorola/perry/*.patch` against
it — applied cleanly, no fuzz, no warnings.

- `0001`: `BoardConfig.mk` — `BOARD_SEPOLICY_DIRS` → `BOARD_VENDOR_SEPOLICY_DIRS`
  pointing at `sepolicy/vendor`; added `TARGET_KERNEL_RECOVERY_CONFIG :=
  perry_recovery_defconfig` (cedric/hannah pattern); switched the vendor
  `BoardConfigVendor.mk` include from `-include` to `include`.
  **Caveat, unverified:** neither `cedric_recovery_defconfig` nor
  `hannah_recovery_defconfig` exist as literal files in
  `kernel/motorola/msm8953`'s `arch/arm/configs` either (checked directly —
  that directory only has generic upstream ARM defconfigs plus an
  `ext_config/` dir of Motorola config *fragments* like `mot8937-perry.config`,
  not full defconfigs named this way). Whatever resolves
  `<device>_recovery_defconfig` into a buildable target is a kernel-side
  mechanism we haven't traced. If the recovery kernel target fails to build,
  start there.
- `0002`: `extract-files.sh` / `setup-makefiles.sh` — renamed the exported env
  var from `DEVICE_COMMON` to `BOARD_COMMON`. This isn't a blanket
  18.1-era rename: checked hannah's own `extract-files.sh` on `lineage-18.1`
  and it still uses `DEVICE_COMMON`, because hannah inherits `hannah-common`,
  a separately-maintained (older-style) common tree. Fetched
  `msm8937-common`'s actual live `extract-files.sh` (the one perry itself
  will invoke, confirmed perry inherits msm8937-common not hannah-common)
  and confirmed *it* reads `BOARD_COMMON`, so cedric's naming is the correct
  contract for perry, not hannah's.
- `0003`: pure rename, `sepolicy/file_contexts` → `sepolicy/vendor/file_contexts`
  (byte-identical content, confirmed via diff before writing the patch).

Deliberately did NOT carry over from cedric's diff: PocketMode
(feature-specific, not present on perry), the `rootdir/etc/init.device.rc`
proximity-sensor lines (same reason), `board-info.txt` (optional baseband
guard; skipped rather than guess the exact required string format), or
`device.mk`'s `inherit-product-if-exists` → `inherit-product` change —
that one's actually wrong for perry: cedric has real committed blobs in
`proprietary_vendor_motorola`, but perry has no such tree at all (confirmed
in the first log entry above); perry's `vendor/motorola/perry/perry-vendor.mk`
is only ever generated locally by `extract-files.sh` from the physical
device, so the conditional `-if-exists` must stay.

Still open, needs the real synced tree + a build attempt to progress further:
HAL versions in `manifest.xml`/compatibility matrices, `proprietary-files.txt`
diffing against perry's actual extracted blobs, and SELinux denial cleanup —
none of these can be drafted blind the way the above could.

## 2026-07-19 — build host confirmed Ubuntu 26.04

Build host is Ubuntu 26.04 LTS (Resolute Raccoon), not 24.04 as originally
written in the scaffold. Updated `scripts/setup-env.sh` to target 26.04;
the libtinfo5/libncurses5 mantic-.deb workaround is unchanged (those packages
are still absent from 26.04's repos). `setup-env.sh` requires sudo for
apt/dpkg steps — run it before the first `sync.sh`.

## 2026-07-19 — session handoff written

Wrote `docs/handoff.md` capturing phase (first full bacon in flight / unproven),
patch inventory, open gaps (XT1765 proprietary rewrite, bacon not green yet),
and next-session research order. Meta-repo was otherwise clean at tip
`00124df` before the handoff commit.

## 2026-07-19 — clone-depth="0" rejected by current repo

`repo sync` failed immediately with:
`clone-depth must be greater than 0, not "0"`. The scaffold used
`clone-depth="0"` as a "full history despite init --depth=1" trick that
older repo treated as falsy; current repo validates `clone-depth > 0` at
manifest parse time. Fix: drop the attribute from `manifests/perry.xml`
and unshallow the four perry-related projects at the end of
`scripts/sync.sh` instead.

## 2026-07-19 — perry_recovery_defconfig kernel patch (WLAN strip)

**Finding:** `TARGET_KERNEL_RECOVERY_CONFIG := perry_recovery_defconfig` in
device-tree patch `0001` pointed at a missing kernel file. Sibling devices
(cedric/hannah/montana) all ship matching `*_recovery_defconfig` files under
`arch/arm64/configs/` that differ from their normal defconfigs **only** by
disabling Pronto WLAN and dropping its dependent options. perry had
`perry_defconfig` but no recovery twin.

**Patch:** `patches/kernel/motorola/msm8953/0001-perry-add-perry_recovery_defconfig-WLAN-stripped.patch`
— generated from `perry_defconfig` (lineage-18.1) by applying the same WLAN
strip as `cedric_defconfig` → `cedric_recovery_defconfig`:
`CONFIG_PRONTO_WLAN=m` → `# CONFIG_PRONTO_WLAN is not set`, and remove the
dependent PRIMA/WLAN options that disappear when Pronto is off
(`CONFIG_PRIMA_WLAN_LFR`, `CONFIG_WLAN_FEATURE_SAE`, `CONFIG_WLAN_AKM_SUITE_OWE`,
`CONFIG_PRIMA_WLAN_LFR_MBB`, `CONFIG_PRIMA_WLAN_OKC`,
`CONFIG_PRIMA_WLAN_11AC_HIGH_TP`, `CONFIG_MDNS_OFFLOAD_SUPPORT`,
`CONFIG_QCOM_TDLS`, `CONFIG_QCOM_VOWIFI_11R`, `CONFIG_WLAN_FEATURE_11W`,
`CONFIG_ENABLE_LINUX_REG`, `CONFIG_WLAN_OFFLOAD_PACKETS`, plus the related
`# CONFIG_* is not set` lines under that block). No other keys differ.
(Earlier log note that recovery defconfigs were absent under
`arch/arm/configs` was looking in the wrong arch tree — see next.)

**Note (arch layout):** msm8937-common on `lineage-18.1` uses `TARGET_ARCH :=
arm64` with `TARGET_2ND_ARCH := arm` (64-bit kernel, 32-bit userspace ABI
available). Device defconfigs therefore live under `arch/arm64/configs/`,
not `arch/arm/configs/`. That is why the earlier `arch/arm/configs` check
missed `cedric_recovery_defconfig` / `hannah_recovery_defconfig` — they are
present on arm64.

**Note (HAL manifests):** HAL versions already live in msm8937-common's
`manifest.xml` on the `lineage-18.1` branch. perry has no device-level
`manifest.xml` and only an `interfaces/` fingerprint extension — no blind
HAL patch needed from cedric's device tree for that part.

**Pending (already in working tree, not committed):** sync fixes for
`clone-depth="0"` rejection — attribute dropped from `manifests/perry.xml`,
unshallow of the four perry-related projects moved into `scripts/sync.sh`
(see previous entry).

## 2026-07-19 — extract-files CLEAN_VENDOR wiped msm8937-common

**Incident:** Running perry's `./extract-files.sh adb` (no flags) wiped
`vendor/motorola/msm8937-common/proprietary/` because msm8937-common's
helper defaults to `CLEAN_VENDOR=true`. That deleted the committed common
APKs (`CneApp`, `QtiTelephonyService`, `datastatusnotification`,
`qcrilmsgtunnel`, etc.) and the next `brunch perry` failed in Soong with
missing module source paths. Restore with:

```bash
cd ~/android/lineage/vendor/motorola
git checkout HEAD -- msm8937-common/proprietary/
```

**Safe perry-only extract** (does not wipe common):

```bash
cd ~/android/lineage/device/motorola/perry
./extract-files.sh -n --only-target adb
# or from the meta-repo:
./scripts/extract-perry.sh adb
```

`-n` / `--no-cleanup` sets `CLEAN_VENDOR=false`; `--only-target` skips the
board-common / device-common extract passes entirely.

**XT1765 blob reality check:** After a safe extract, only **26 / 99**
entries from `proprietary-files.txt` exist on stock 7.1.2. Many listed
paths are montana leftovers (FPC fingerprint HAL, `*-montana.tdat` touch
firmware, `s5k3p3` / `s5k3p8sp` / `ov5695_l5695f60` chromatix). This
XT1765 actually has **imx219 / ov5695 / s5k4h8** camera libs under
`/system/vendor/lib/` and **egis** fingerprint firmware
(`egtzappfingerprint.*`), not FPC. `proprietary-files.txt` needs a
rewrite against a full stock inventory before camera/FP will package
correctly. For now `perry-vendor.mk` was regenerated locally to list only
the 26 files present on disk so the build does not fail on missing
`PRODUCT_COPY_FILES` sources.

**Also fixed this session:**
- Kernel: no `git am` in progress; `perry_recovery_defconfig` is present
  under `arch/arm64/configs/` (applied earlier).
- `dtbtool`: `BUILD_HOST_EXECUTABLE` is obsolete on 18.1 — converted to
  Soong `cc_binary_host` (`patches/.../0004-...`).
- `extract-files.sh`: warning comment + best-effort fixups
  (`patches/.../0005-...`).


## 2026-07-19 — msm8937-common Android.mk omitted perry

First `brunch perry` passed Soong APK checks (after proprietary restore)
and the dtbtool Soong conversion, then failed at makefile analysis:

`updater ... missing librecovery_updater_motorola (STATIC_LIBRARIES android-arm64)`

Root cause: `device/motorola/msm8937-common/Android.mk` gates
`all-makefiles-under` (including `recovery/` which builds
`librecovery_updater_motorola`) behind

`filter ahannah cedric hannah james montana rhannah`

— perry was never added when the common tree grew that list. Patch:
`patches/device/motorola/msm8937-common/0001-...` adds `perry` to the
filter.



## 2026-07-19 — OMX V4L2 undeclared identifiers (libOmxVdec/libOmxVenc)

`brunch perry` failed compiling `hardware/qcom-caf/msm8996` media:

- `V4L2_QCOM_CMD_FLUSH` (omx_vdec_v4l2.cpp / video_encoder_device_v4l2.cpp)
- `V4L2_MPEG_VIDEO_H264_LEVEL_UNKNOWN` (omx_vdec_v4l2.cpp)

**Root cause:** `msm8937-common` sets `TARGET_KERNEL_VERSION := 4.9`
(commit `b4adeb5`), which makes the msm8996 CAF media HAL define
`_TARGET_KERNEL_VERSION_49_` and take the 4.9 ioctl/enum names. Perry's
`kernel/motorola/msm8953` on `lineage-18.1` is still 3.18.140 with
3.18-style uapi (`V4L2_DEC_QCOM_CMD_FLUSH` / `V4L2_ENC_QCOM_CMD_FLUSH`,
no `LEVEL_UNKNOWN`). `BoardConfigQcom.mk` maps `msm8937` →
`QCOM_HARDWARE_VARIANT := msm8996` (UM_3_18_FAMILY), so this HAL path is
expected.

`moto-msm89xx` `staging/lineage-18.1` already has the unified
`V4L2_QCOM_CMD_FLUSH` and `LEVEL_UNKNOWN` in uapi; shipping `lineage-18.1`
does not. Sibling device trees (cedric/hannah) inherit the same common
flag and would hit the same gap against this kernel tip.

**Fix:** minimal uapi shim (keep DEC/ENC names the driver switch still
uses; add aliases with the same numeric values):

- `include/uapi/linux/videodev2.h`: `#define V4L2_QCOM_CMD_FLUSH (4)`
- `include/uapi/linux/v4l2-controls.h`: `V4L2_MPEG_VIDEO_H264_LEVEL_UNKNOWN = 17`

Patch: `patches/kernel/motorola/msm8953/0002-uapi-add-V4L2-macros-for-CAF-media-HAL-TARGET_KERNEL.patch`
(applied on the live tree). Did **not** unset `TARGET_KERNEL_VERSION` —
common intentionally opted into the 4.9 HAL path for 18.1.


## 2026-07-19 — fingerprints HIDL root still pointed at montana

After the OMX uapi fix, `m bacon` failed at ~35% on:

`hidl-gen ... -rcom.fingerprints:device/motorola/montana/interfaces`
→ `Could not open package path device/motorola/montana/interfaces/extension/1.0/`

`device/motorola/perry/interfaces/Android.bp` still had montana's path
(montana leftover). HALs are under perry. Patch
`patches/device/motorola/perry/0006-...` retargets the package root.


## 2026-07-19 — fc_sort IndexError on vendor_file_contexts

`m bacon` reached ~85% then failed in `fc_sort` on
`vendor_file_contexts` (`IndexError: list index out of range` at
`context.split(":")[2]`).

Root cause: `device/motorola/perry/sepolicy/vendor/file_contexts` had no
trailing newline. With `m4 -s` concatenating inputs, the next file
(`device/lineage/sepolicy/common/vendor/file_contexts`, starting with
`# Fingerprint HAL`) was glued onto the last context token:

`...hal_fingerprint_default_exec:s0# Fingerprint HAL`

Patch `0007-sepolicy-ensure-file_contexts-ends-with-newline.patch` adds the
EOF newline. Confirmed `fc_sort` succeeds on the regenerated m4 output.


## 2026-07-19 — apexer mke2fs orphan_file on Ubuntu 24.04+

`m bacon` cleared sepolicy/`fc_sort`, then failed at ~94% packaging
`com.android.art.release` APEX:

`Invalid filesystem option set: ... orphan_file`
(apexer → host `out/.../mke2fs` 1.45.4 reading `/etc/mke2fs.conf`)

Ubuntu 24.04+ enables `orphan_file` in `/etc/mke2fs.conf`; Lineage 18.1's
bundled mke2fs cannot apply that feature set. Fix: ship
`config/mke2fs.conf` (ext4 features without `orphan_file`), install to
`$HOME/android/mke2fs.conf`, and `export MKE2FS_CONFIG=...` from
`scripts/setup-env.sh` / `~/.bashrc`.
