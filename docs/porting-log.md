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


## 2026-07-19 — apexer mke2fs orphan_file on Ubuntu 24.04+ / 26.04

`m bacon` cleared sepolicy/`fc_sort`, then failed at ~94% packaging
`com.android.art.release` APEX (`logs/brunch-perry-20260719-172106.log`):

`Invalid filesystem option set: ... orphan_file`
(apexer → tree `mke2fs` 1.45.4 reading `/etc/mke2fs.conf`)

Ubuntu 24.04+/26.04 enable `orphan_file` in `/etc/mke2fs.conf`; Lineage 18.1's
bundled mke2fs cannot apply that feature set. Fix committed as `9f13fcd`:
`config/mke2fs.conf` (no `orphan_file`), install to `$HOME/android/mke2fs.conf`,
`export MKE2FS_CONFIG=...` from `scripts/setup-env.sh` / `~/.bashrc`.

**Handoff note:** the 172106 bacon process did not inherit `MKE2FS_CONFIG`
(build shell never sourced bashrc). Next session must export it explicitly
before `m bacon`. Handoff doc rewritten EOD 2026-07-19 for a clean pickup.


**Follow-up:** `MKE2FS_CONFIG` alone is not enough — `soong_ui` filters the
ninja environment and drops it unless allowlisted. Perry
`BoardConfig.mk` now has `BUILD_BROKEN_NINJA_USES_ENV_VARS += MKE2FS_CONFIG`
(patch `0008`).


## 2026-07-19 — OTA VINTF: no kernel entry for 3.18 at FCM 4

ART APEX packaging succeeded after the mke2fs allowlist. `m bacon` then
failed at `ota_from_target_files` / `checkvintf`:

`No kernel entry found for kernel version 3.18 at kernel FCM version 4`

msm8937-common sets `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := true`
(for a 4.9-oriented tree), but perry's built kernel is still 3.18.140 and
Android 11 FCM level 4 does not define 3.18 kernel config requirements.
Override to `false` in perry `device.mk` (patch `0009`).


## 2026-07-19 — first successful `m bacon` for perry

After the VINTF kernel-enforce override, bacon completed successfully
(`BACON_RC=0`, ~6 min incremental):

`out/target/product/perry/lineage-18.1-20260720-UNOFFICIAL-perry.zip`
(~699 MB; also `lineage_perry-ota-eng.aneesh.zip`).

Build host was Ubuntu 26.04 in this session. Next: flash via TWRP
(`fastboot boot` preferred), expect bootloop, debug with `adb logcat` /
`/proc/last_kmsg`. Do not wipe `persist` / EFS.

## 2026-07-19 — first flash: N/A loop = kernel panic (USB configfs)

Flashed `lineage-18.1-20260720-UNOFFICIAL-perry.zip`. Symptom: screen
shows "N/A" top-left, blanks, reboots. ROM never enumerated adb (USB
watches only saw `22b8:2e80` fastboot flickers).

**Fastboot UTAG (cleared):** early `getvar reason` was
`UTAG "bootmode" configured as fastboot`. Cleared with
`fastboot oem fb_mode_clear`. After that, real boot attempts happened
(N/A loop) instead of forced fastboot.

**LOS recovery.img** (`fastboot boot` from tree) also failed to bring up
adb — same USB stack as the ROM kernel.

**TWRP (omni_perry already on device)** had working adb. Pulled pstore
(not `/proc/last_kmsg` — absent on this recovery):

`~/android/lineage/logs/boot/twrp-20260719-185648.pstore/`
(`annotate-ramoops-0`, `console-ramoops`, `dmesg-ramoops-0`)

**Panic:** ~7.1s into boot, `init` runs `init.msm.usb.configfs.rc` while
kernel has `# CONFIG_USB_CONFIGFS is not set` + `CONFIG_USB_G_ANDROID=y`,
but cmdline has `androidboot.usbconfigfs=true` (from msm8937-common).
Duplicate sysfs under `android_usb`/`f_audio_source/pcm` →
`BUG_ON` in `sysfs_create_file_ns` → `Kernel panic - not syncing: Fatal
exception`. Boot reason: `kernel_panic`.

**Expected fix:** enable kernel USB configfs (and reconcile G_ANDROID),
*or* perry override to legacy android_usb (drop configfs cmdline + init).
Research how cedric/hannah 18.1 handled the same common cmdline.

**Also downloaded** official `twrp-3.7.0_9-0-perry.img` to
`~/android/recovery/` for the TWRP rebuild side quest. Handoff rewritten
to pause LOS boot debug on this panic and shift to building latest TWRP.

## 2026-07-19 — local TWRP 3.7.0_9-0 rebuild for perry

Rebuilt official TeamWin perry TWRP matching Jenkins `perry-prod` /
dl.twrp.me `twrp-3.7.0_9-0-perry.img`:

- Tree: `~/android/twrp` — `minimal-manifest-twrp` branch `twrp-7.1`
  (Omni 7.1.2), device `TeamWin/android_device_motorola_perry` @
  `android-7.1` (prebuilt kernel/dt).
- Xylitol: `manifests/twrp-perry.xml`, `scripts/sync-twrp.sh`,
  `scripts/build-twrp.sh`.

Ubuntu 26.04 host issues fixed:
1. OpenJDK 8 for Omni.
2. Python 2.7 via micromamba (`~/android/mamba/envs/py27`) — Omni
   `build/tools` are py2; no system python2 on 26.04.
3. Prebuilt `flex-2.5.39` aborts on glibc 2.43+ locales — wrapped to
   system `/usr/bin/flex` (`flex-2.5.39.broken` kept).
4. `make recoveryimage` size-assert fails: img 17412096 B vs recovery
   partition `0x1019000` (16879616 B). Official download is the **same
   size**; image is still produced. Use `fastboot boot` only (do not
   flash until shrunk or partition story clarified).

Verified: `fastboot boot ~/android/recovery/twrp-perry-local-latest.img`
→ adb recovery, `ro.twrp.version=3.7.0_9-0`,
`eng.aneesh.20260719.191216`, pstore accessible.

## 2026-07-19 — USB panic research: siblings, official LOS, root cause confirmed

Researched handoff §3 question ("do cedric/hannah 18.1 enable configfs or
carry USB patches we missed?"). Answer: **neither — the configfs userspace
itself is the bug, and official LineageOS never used it.**

Findings, each verified in-tree or against GitHub:

1. **Kernel (moto-msm89xx `lineage-18.1`):** every device defconfig —
   perry, cedric, hannah, montana, jeter, owens, potter, sanders — has
   `# CONFIG_USB_CONFIGFS is not set` + `CONFIG_USB_G_ANDROID=y`. Perry's
   USB config is byte-identical to cedric's. `git log --all -S
   "CONFIG_USB_CONFIGFS=y"` over `arch/arm64/configs/`: no moto-msm89xx
   branch (incl. `staging/lineage-18.1`) ever enabled it. There is no
   hidden sibling kernel fix.
2. **The regression:** msm8937-common `e8faebe` ("Enable USB configfs and
   add init script", Feb 2020, on 18.0/18.1 only — 17.1 never had it)
   deleted legacy `init.mmi.usb.rc`, added `init.msm.usb.configfs.rc`, and
   appended `androidboot.usbconfigfs=true` to `BOARD_KERNEL_CMDLINE` — with
   no kernel counterpart, ever.
3. **Panic mechanism:** in this QC 3.18 tree `configfs.o` is part of
   `libcomposite` **unconditionally** (`drivers/usb/gadget/Makefile:10`),
   so `/config/usb_gadget` exists even without `CONFIG_USB_CONFIGFS`.
   `G_ANDROID`'s `android.c` instantiates functions at probe
   (`usb_get_function_instance("audio_source")` → creates
   `android0/f_audio_source` + `pcm` attr). The rc's unconditional
   `on init` mkdirs then re-enter the same singleton allocators:
   `mtp.gs0`/`accessory.gs2` → EBUSY; `audio_source.gs2` → duplicate sysfs
   WARN; `audio_source.gs3` → `BUG_ON` in `sysfs_create_file_ns`
   (NULL kobj) → panic. Confirmed against pstore `console-ramoops`
   (mkdir at rc line 41 fails EINVAL between WARN and BUG).
4. **`androidboot.usbconfigfs=true` comes from our boot.img**, not the
   bootloader: in the pstore cmdline it sits inside the BoardConfig-derived
   segment, before the bootloader-appended `androidboot.*` block.
5. **Official LineageOS 18.1 (proven booting, shipped cedric builds):**
   `LineageOS/android_device_motorola_msm8937-common` `lineage-18.1` has
   **no** `usbconfigfs` in cmdline, ships legacy `init.mmi.usb.rc`
   (functionfs adb: `mount functionfs adb`, `f_ffs/aliases adb`,
   `sys.usb.ffs.aio_compat=1` — the Android 11 adbd compat knob), sets
   `sys.usb.configfs 0`. Its kernel
   (`LineageOS/android_kernel_motorola_msm8953` `lineage-18.1`,
   cedric_defconfig) is likewise `G_ANDROID=y`, configfs unset. So
   Android 11 + legacy android_usb is a shipped, working combination on
   this exact SoC family/kernel.

**Decision: fix B (legacy android_usb), implemented at msm8937-common
level** — effectively revert `e8faebe`, preferring official LineageOS
18.1's `init.mmi.usb.rc` verbatim over the pre-e8faebe 17.1-era file
(official's is already 18.1-tuned, incl. `aio_compat`). Changes: drop
`androidboot.usbconfigfs=true` from `BOARD_KERNEL_CMDLINE`; swap
`init.msm.usb.configfs.rc` → `init.mmi.usb.rc` in `msm8937.mk`,
`rootdir/Android.mk`, and the `init.mmi.rc` import; add the official rc
file. Record as `patches/device/motorola/msm8937-common/0002`. Fix A
(enable configfs) rejected: zero reference material in the family, and
would fight `android.c`'s probe-time function instantiation. Side
benefit: dropping the cmdline flag also flips recovery's
`init.recovery.usb.rc` selection back to the legacy path, which should
un-break adb in the LOS recovery image too.

## 2026-07-19 — TWRP made flashable (shrink BoardConfig)

Recovery partition is `0x1019000` (16879616). Unmodified TeamWin flags
built a 17412096 image (~532KB over) — same as official download, fine for
`fastboot boot`, not for `fastboot flash`.

Fix in `device/motorola/perry/BoardConfig.mk` (xylitol patch
`patches/twrp/device/motorola/perry/0001-BoardConfig-shrink-recovery-to-fit-partition.patch`):
- `TW_EXTRA_LANGUAGES := false`
- `TW_EXCLUDE_BASH := true` / `TW_EXCLUDE_NANO := true` (drops ~6.6MB terminfo)
- omit `TW_INCLUDE_FB2PNG`, logcat/logd

Result: ramdisk LZMA ~4.6MB, recovery.img **14219264** (fits). `make`
size-assert passes. `fastboot flash recovery` OKAY on XT1765 (unsigned
warning normal when unlocked).

## 2026-07-19 — USB fix implemented: msm8937-common patches 0002/0003

Implemented the fix-B decision from the research entry above, as two
commits on the live msm8937-common tree, exported to
`patches/device/motorola/msm8937-common/`:

- **0002 `msm8937-common: switch USB init back to legacy android_usb`**
  — drops `androidboot.usbconfigfs=true` from `BOARD_KERNEL_CMDLINE`;
  deletes `init.msm.usb.configfs.rc`; adds `init.mmi.usb.rc` verbatim
  from official `LineageOS/android_device_motorola_msm8937-common`
  `lineage-18.1` (`ae102af`); rewires `msm8937.mk`,
  `rootdir/Android.mk`, and the `init.mmi.rc` import. With the configfs
  rc gone nothing sets `sys.usb.configfs=1`, so `init.usb.rc`'s default
  `0` keeps init on the legacy `android_usb` sections.
- **0003 `msm8937-common: don't force sys.usb.configfs in recovery`**
  — reverts upstream `ee6f276` (`setprop sys.usb.configfs 1` in
  `init.recovery.qcom.rc`), which is why the LOS recovery image never
  enumerated adb.

Verified: `git am` of the full 0001–0003 series applies clean on a
fresh clone of moto-msm89xx `lineage-18.1`.

Next: `m installclean` (BoardConfig changed) + `m bacon`, flash zip via
TWRP (`fastboot boot`, never flash recovery), expect `18d1:*`
enumeration during boot; if still looping, pull pstore and check the
audio_source BUG is gone.

## 2026-07-19 — USB fix verified on device; FBE blocker → patches 0004/0005

Flashed the rebuilt zip (kernel `#7`): **USB panic is gone** — pstore
shows a clean run past 7.1s, no BUG, no panic. Boot now dies at ~9.4s in
userspace: `init: /data is file encrypted` → `Failed to set encryption
policy ... Operation not supported` → orderly `Rebooting into recovery`
(device reappears in TWRP; earlier "reboot loop" symptom is now
understood as this).

Root cause, same disease as USB: fstabs request FBE
(`fileencryption=ice`) but no branch of the kernel has
`CONFIG_F2FS_FS_ENCRYPTION` (not even the `fbe` branch). **Key
discovery:** moto-msm89xx's 18.1 common tree was written against
`staging/lineage-18.1`, an unfinished **4.9** CAF kernel import (no
device defconfigs, no perry DTS — dead end for perry); hence
`TARGET_KERNEL_VERSION := 4.9`, configfs USB, FBE, and 4.9 sysfs paths
against our actual 3.18 kernel. Standing strategy: stay on 3.18, align
userspace to official LineageOS 18.1 (which shipped FDE +
legacy-android_usb + 3.18 paths on this kernel).

New patches (both `git am`-verified in series 0001–0005 on fresh clone):

- **0004 `switch /data from FBE to FDE-capable`** — both fstabs: drop
  `fileencryption=ice`, keep `encryptable=<metadata>` (official uses
  `forceencrypt`; `encryptable` chosen for bring-up so TWRP can read
  /data — flip before release). Drops FBE-only
  `ro.crypto.volume.filenames_mode` prop.
- **0005 `revert vold sysfs paths to 3.18`** — sdcard/OTG voldmanaged
  paths back to `/devices/soc/...` (moto's `/devices/platform/soc/...`
  is the 4.9 location; SD/OTG would never be detected).

Also decided with user: format /data before next boot (half-initialized
FBE state from the failed boot; persist/modemst untouched).

Remaining known 4.9-isms to watch: `TARGET_KERNEL_VERSION := 4.9` in
BoardConfigCommon.mk (kernel patch 0002 works around the V4L2 side) —
audit for other sysfs-path assumptions if devices misbehave post-boot.

## 2026-07-19 — FDE fix verified; bpfloader loop → patch 0006

Flashed the FDE build after formatting /data. **Crypto blocker cleared**
— boot now passes mount + encryption and runs to full userspace, but
loops every ~30s: `bpfloader` exits 2 → init `reboot_on_failure` →
`reboot,bpfloader-failed` (pstore). From the host, the loop is USB-
silent (legacy gadget never configured before the reboot); the device
eventually fell through fastboot into the flashed omni_perry TWRP.

Root cause — 4.9-ism #4: `ro.kernel.ebpf.supported=true` in
`properties.mk` (54e26d2) forces bpfloader past its support check onto
a kernel with `CONFIG_BPF_SYSCALL` unset (`loadAllElfObjects` fails →
exit 2). Official LineageOS 18.1 does not set the prop; its kernel is
identically eBPF-less, and with `first_api_level=25` + kver<4.9,
`BpfUtils.cpp` resolves `BpfLevel::NONE` and bpfloader exits 0.

**0006 `don't claim eBPF support on 3.18`** — removes the prop.
Verified in series 0001–0006 with `git am` on fresh clone.

Score so far on the "staging-4.9 userspace vs real 3.18 kernel" theory:
USB configfs, FBE, vold sysfs paths, eBPF — four for four.

## 2026-07-19 — 🎉 FIRST BOOT: LineageOS 18.1 boots on perry

Flashed the 0006 build: **full boot to UI**. `sys.boot_completed=1`,
zygote up, Settings/SystemUI rendering, touch working, adb up in-ROM
via the legacy gadget (`product:perry_retail`, `device` state — the
0002 USB fix working end-to-end). SELinux **Enforcing** with zero avc
denials in dmesg at 7 min uptime. Bootreason: plain `reboot`.

The four staging-4.9 reverts (USB configfs → legacy android_usb, FBE →
FDE-capable, vold sysfs paths → 3.18, eBPF claim removed) were the
complete set of boot blockers after the already-fixed build issues.
Series `patches/device/motorola/msm8937-common/0001–0006` +
`perry/0001–0009` + `kernel/0001–0002` = bootable ROM from clean sync.

Next phase — hardware bring-up audit: RIL/data (XT1765 GSM), Wi-Fi,
BT, camera, audio, sensors, GPS; then the XT1765 proprietary-files
rewrite (stock build id conflict note in handoff §research-5), then
decide encryptable→forceencrypt before any daily-drive/release.

## 2026-07-19 — Wi-Fi fixed (kernel 0003); first-boot triage notes

**Wi-Fi:** dead because `perry_defconfig` had `CONFIG_PRONTO_WLAN=m` and
nothing in 18.1 userspace loads wlan.ko — official/cedric build it in
(`=y`, kernel commit 612c0467 did exactly this for cedric; perry's
defconfig missed it). Verified by manual insmod on the live device
(firmware + wlan0 came up instantly; HAL still failed with
`configureChip error: 9` from stale driverless state — runtime load
isn't viable, built-in is required). **Kernel patch 0003
`perry: re-inline pronto WLAN driver`** (=y). After rebuild+flash:
wlan0 up at boot, framework enabled, 2.4+5 GHz scan works, associates
to AP with status-bar signal. FIXED.

**"Boots to home screen" (user report):** no PIN set
(`CredentialType: None`) and SystemUI crashed once right at
first-boot/setup time (KeyguardService DeadObjectException, stack
rotated out of buffer), skipping the swipe keyguard. On the next clean
boot SystemUI had zero deaths. Treat as one-off unless it recurs —
re-check on future reboots.

**Standing issues found in triage (next session):**
1. **Camera stack crash-loop** (recurs every boot): vendor
   `camera.provider@2.5-service` SEGV (null deref) in
   `CameraModule::notifyDeviceStateChange` via 2.5→2.4 legacy wrapper;
   takes cameraserver down (abort in `assertOk`). Known old-blob issue
   class — needs the notifyDeviceStateChange guard/shim.
2. **hal_health sepolicy denial** (benign but noisy, every ~20 s):
   `hal_health_default` read on sysfs `type` files — first entry for
   the sepolicy pass.
3. RIL/mobile network: untouched (Settings shows it greyed) — XT1765
   proprietary rewrite phase.

## 2026-07-19 — Navbar missing (no back/home/recents): root-caused

User report: no navigation at all. Two stacked causes:

1. All `com.android.internal.systemui.navbar.*` RRO overlays were
   disabled (even `threebutton`, normally default-on). Enabled
   `threebutton` via `cmd overlay enable-exclusive` — persists in the
   /data overlay store.
2. Deeper: framework thinks perry has hardware keys.
   `init.qcom.sh` sets `qemu.hw.mainkeys 0` only for soc_ids
   317/318/324–327 (msm8937/8940 family) — perry's msm8917 is
   **soc_id 303**, not in the list, and no device tree sets
   `config_showNavigationBar`. So `mHasNavigationBar=false` and no
   navbar (and no gesture nav either) regardless of overlay.

**Fix for next build:** add `qemu.hw.mainkeys=0` to perry's
`PRODUCT_PROPERTY_OVERRIDES` (device/motorola/perry) — perry-specific,
E4 stock uses an on-screen navbar. (Alternative: add soc_id 303 to the
init.qcom.sh case; prop is simpler and boot-order-safe.) Not yet
patched — queued for next session's batch.

## 2026-07-19 — Navbar fix patched (0010); verified on device

Added `qemu.hw.mainkeys=0` to `device/motorola/perry/vendor_prop.mk`
via patch `0010-perry-force-soft-navigation-bar-qemu.hw.mainkeys-0.patch`.
Full perry series `0001`–`0010` `git am`-verified clean against a fresh
`lineage-17.1` clone. Applied live (`ad4f633`).

**On-device verify:** perry has no GPT `vendor` — Lineage mounts
`oem` as `/vendor` (TWRP fstab). Injected the prop into
`/vendor/build.prop` from TWRP; also rebuilt `vendor.img` (contains
`qemu.hw.mainkeys=0`; flash as `oem` if needed). After reboot:
`getprop qemu.hw.mainkeys` → `0`, `NavigationBar0` present,
`ITYPE_NAVIGATION_BAR ... visible=true`. Threebutton overlay was
already enabled on /data.

Build notes: interrupting bacon dirties `out/` heavily. On Ubuntu
26.04 put `prebuilts/python/linux-x86/2.7.5/bin` first on `PATH` or
`insertkeys.py` fails (`ConfigParser`). Fastboot `flash vendor`
fails (Invalid partition name); use `oem` or TWRP.

## 2026-07-19 — msm89x7-mainline org research (side-quest recon; nothing to integrate into 18.1)

Surveyed github.com/msm89x7-mainline on request. Five repos:

| Repo | What it is | Relevance |
|---|---|---|
| `linux` | Active mainline fork for MSM8917/37/40, SDM429/439, QM215; branches track upstream to 7.1 (default `msm89x7/7.1.3`, pushed same day) | Side quest only |
| `lk2nd` | **Archived** fork — live lk2nd is `msm8916-mainline/lk2nd`, which lists perry (MSM8917 *and* MSM8920 variants) as supported | Side quest only |
| `msm-4.9` | CodeLinaro downstream `LA.UM.9.8.c26`, kept "for reference" | Reference only |
| `linux-panel-drivers` | Generated DSI panel drivers (no perry config; nora/cedric/hannah/montana present) | Side quest only |
| `alsa-ucm-conf` | UCM profiles for the mainline audio path | Side quest only |

Headline: **perry mainline support exists as open PR
msm89x7-mainline/linux#48** ("arm64: add support for MSM8920, add support
for motorola-perry", opened 2026-04-18, updated 2026-07-13, author
agrecascino). Adds `msm8917-motorola-perry.dts` +
`msm8920-motorola-perry.dts` over a 533-line common dtsi: Tianma 499v1
panel, Synaptics RMI4 touch (blsp1_i2c3), WCN3660B iris (Wi-Fi/BT), modem +
ADSP/APR audio, GPU, venus, PMI8950 smbcharger/fg/WLED, BMA253 on i2c-gpio.
Only public perry mainline DTS anywhere on GitHub (global code search for
`msm8917-motorola-perry` hits lk2nd + this PR only).

pmOS wiki (Motorola Moto E4 (motorola-perry)): boots via the **generic
`qcom-msm89x7` device package** — there is deliberately no
`device-motorola-perry` package, which is why naive pmaports searches come
up empty. Kernel 6.19.5, lk2nd flashed to boot. Working:
screen/touch/Wi-Fi/BT/audio/3D/battery/USB/OTG. Partial: calls/SMS/mobile
data. Broken: camera. Caveat: PR #48 unmerged → the packaged
`linux-postmarketos-qcom-msm89x7` may not ship the perry DTB yet; verify
before flashing. Wiki page describes the MSM8920 SKU; ours (XT1765) is the
MSM8917 DTS in the same PR.

**Integration verdict for the LineageOS 18.1 port: none.**
- Mainline kernel under LineageOS is infeasible: the 32-bit Nougat blob
  stack needs downstream 3.18 interfaces (ION, mdss, KGSL + Adreno
  userspace, prima/pronto WCNSS). Mainline replaces all of those with
  DRM/freedreno/wcn36xx — open drivers no HAL in our tree can talk to.
- `msm-4.9` as a 3.18→4.9 uplift is a trap: same-family silicon support
  exists (QM215/SDM429), but no moto-msm89xx device ever made the jump,
  Moto-specific drivers would need forward-porting, and camera/sensor blobs
  are kernel-ABI fragile. Months of work, zero 18.1 benefit. Use it the way
  the org does: as a reference when downstream driver behavior is unclear.
- lk2nd is orthogonal (stock aboot already does `fastboot boot`; lk2nd would
  occupy the boot partition and complicate ROM flashing).

Kept: CLAUDE.md side-quest section rewritten with the above; PR #48's DTS
noted as the best public hardware map of perry (part numbers + buses) for
future HAL/sepolicy debugging.

## 2026-07-19 — FM radio dead: sepolicy + unset init prop

User confirmed soft navbar works. New report: FM app does nothing.

Recon: msm8937-common already packages `FM2` / `libqcomfm_jni` /
`qcom.fmradio`; perry `mixer_paths.xml` has full `play-fm` /
`capture-fm` paths; props `ro.fm.transmitter=false`,
`ro.vendor.fm.use_audio_session=true`. Hardware is expected — mainline
perry DTS ([msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48))
sets `&wcnss_iris { compatible = "qcom,wcn3660b"; ... }` (Iris FM path
shared with Wi-Fi/BT).

Launching `com.caf.fmradio/.FMRadio` under Enforcing spam-denies:
`vendor_fm_app` read on `vendor_fm_prop` / `vendor.hw.fm.init`. Prop is
unset. `device/qcom/sepolicy-legacy-um/legacy/vendor/common/fm_app.te`
never `get_prop(vendor_fm_app, vendor_fm_prop)` — only `system_app.te`
has that allow. Fix candidate: perry or common sepolicy patch adding
the get_prop (and ensure qti_init_shell still sets the prop). Retest
with wired headset (antenna). Queued as handoff P2-#4.

## 2026-07-19 — Camera crash: missing HAL (not notifyDeviceStateChange)

**Symptom:** `camera.provider@2.5-service` SEGV in
`CameraModule::notifyDeviceStateChange` (fault addr `0x8`) every few
seconds; cameraserver aborts with it.

**Root cause (Phase 0 live probe):** primary failure is
`CamPrvdr@2.4-legacy: Could not load camera HAL module: -2` —
`/vendor/lib/hw/camera.msm8937.so` was never packaged. The SEGV is
secondary: `@2.5-service` still `registerAsService` when init fails
(unlike 2.4 `HIDL_FETCH`), then cameraserver calls
`notifyDeviceStateChange` on a null `mModule`.

**Phase 0:** Injected montana `camera.msm8937.so` (+
`libmmcamera_interface` / `libmmjpeg_interface`) via TWRP onto oem.
TWRP-pushed files landed as `u:object_r:system_file:s0` →
`hal_camera_default` getattr denial still surfaced as ENOENT. After
`chcon u:object_r:vendor_file:s0`, provider opened the HAL
(`/proc/<pid>/fd → camera.msm8937.so`). Path/name confirmed.

**Packaging bugs found:**
1. `device.mk` never inherited `montana-vendor.mk` (only empty
   `BoardConfigVendor.mk`).
2. Hand-trimmed `perry-vendor.mk` used dest
   `$(TARGET_COPY_OUT_VENDOR)/vendor/...` → `/vendor/vendor/lib/`
   (fixed locally: strip the extra `vendor/`).
3. XT1765 sensors are **imx219 / s5k4h8 / mot_ov5695** (device XML);
   montana chromatix leftovers remain in `proprietary-files.txt`.
   No stock dump on host — sensor libs still need stock re-extract.

**Phase 2:** Added `camera-vendor.mk` (87 SoC platform blobs from
montana proprietary) + inherit from `device.mk`. Exported
`patches/.../0011-perry-ship-msm8937-camera-platform-stack-from-montana.patch`.
Vendorimage rebuild in flight; flash next, then stock sensor extract.

## 2026-07-19 — Camera Phase 2: platform stack packaging + first flash

**0011** `camera-vendor.mk`: pulls 90+ msm8937 camera platform blobs from
montana proprietary (HAL, mm-qcamera-daemon, MCT/ISP, jpeg). Applied live
on perry tree (`6e32be2`).

**Flash lesson:** `out/.../vendor.img` is Android **sparse**. Raw `dd` to
oem corrupts the FS (TWRP "Invalid argument"); convert with `simg2img`
first, then `dd` the raw ext4 image. Documented for cheat sheet.

**After correct flash:**
- `camera.msm8937.so` present, labeled `vendor_file` by packaging
- `provider@2.5-service` + `cameraserver` stay up (no more
  notifyDeviceStateChange SEGV loop)
- Provider blocks in `msm_sensor_init_subdev_ioctl` (kernel contact!)
- `dumpsys media.camera`: still **0 devices** — daemon not healthy yet
- Dep whack-a-mole on `mm-qcamera-daemon`: fixed `lib_mot_app6_metadata`
  via live inject; next `libgralloc1.so` (via `libmot_gpu_mapper.so`)
- XT1765 sensor libs (imx219/s5k4h8) still absent — stock extract needed
  for actual capture even after daemon links

Also fixed hand-trimmed `perry-vendor.mk` double `/vendor/vendor/` dest
paths locally (regenerate via setup-makefiles when rewriting
proprietary-files).

## 2026-07-20 — Camera: gralloc1-inclusive vendor flashed — daemon STABLE ✅

The pending `/tmp/perry-camera-recon/vendor-raw.img` was lost to a host
reboot; regenerated with `simg2img` from `out/.../vendor.img` (Jul 19
23:21 build — confirmed newer than the staged `libgralloc1.so`, 23:09,
so it is the gralloc1-inclusive image). Flashed per cheat sheet (TWRP
`dd` to oem); verified on-partition before reboot: `camera.msm8937.so`,
`mm-qcamera-daemon`, `libgralloc1.so` all present.

**After boot (~60 s):**
- `init.svc.vendor.qcamerasvr` = **`running`** (was `restarting` —
  baseline re-confirmed pre-flash). Provider@2.5 + cameraserver also
  running; `mm-qcamera-daemon` steady in `do_select`, not looping.
- **Zero `CANNOT LINK` / dlopen failures** in logcat (only unrelated
  `libjni_latinimegoogle`). The link-dep whack-a-mole is done — patch
  **0011** is verified end-to-end on device.
- `dumpsys media.camera`: still **0 devices — expected.** XT1765 sensor
  libs (imx219 / s5k4h8 / mot_ov5695 + dw9718s actuator + chromatix)
  aren't packaged; that's the stock-dump ingest (handoff §4). Notably
  the provider now exports **97 qcamera3 vendor tags** — the HAL is
  genuinely initialized, not stubbed.
- Kernel-side: two early-boot `msm_eeprom_platform_probe failed 2192`
  lines. Watch when sensor libs land — eeprom/OTP may matter for AF/AWB
  calibration data.

Camera bring-up now blocks solely on the stock 7.1.1 dump.

## 2026-07-20 — Side quest recon: the staging-4.9 kernel is viable (parked; plan written)

Asked: can we patch `staging/lineage-18.1` (the unfinished 4.9 kernel the
18.1 platform branches were written for) to work with our current build?
Recon verdict: **yes, feasibly — weeks-scale, not months** — the earlier
"dead end for perry" note was true only of the *Motorola layer*, not the
platform. Full plan: `docs/kernel-4.9-plan.md`. Parked behind camera/RIL.

**What the staging branch actually is** (verified via GitHub API):
CAF msm-4.9.**227**, current to mid-2021 (QBG uapi era), in
`moto-msm89xx/android_kernel_motorola_msm8953`. Not a stub: complete
generic MSM8917/8937 support — `msm8937`/`msm8937go` defconfigs (arm +
arm64), full msm8917 CDP/MTP/QRD DTS stack (cpu/gpu/mdss/ion/bus/camera/
pinctrl) — plus org-added `drivers/staging/prima` (our WCN3660B),
`techpack/audio`, sdfat, and CAF `synaptics_dsx`/`_2.6` touch.

**What's missing = Motorola only.** From our 3.18 tree, perry's Moto
kernel surface: DTS chain `msm8917-perry-p0.dts` → `msm8917-perry.dtsi` +
`msm8917-moto-common.dtsi` (500 L) + `msm8917-perry-common.dtsi` (315 L)
+ `msm8917-camera-sensor-mot-perry.dtsi` (351 L) + tianma/ofilm-499
panel dtsis + gk40 batterydata ≈ **1.7–2k lines to translate**; drivers:
`drivers/misc/utag` (`mmi,utags`), Egis `et320` fingerprint,
`mmi,alsa-to-h2w` / `mmi,sys-temp` glue; Moto `synaptics_dsx_i2c` vs CAF
dsx to reconcile. Sensor compatibles (bma253/ak09911/epl8802/sx9310) are
likely ADSP-side config — verify. Note perry builds an **arm64 kernel**
(defconfig lives in `arch/arm64/configs`) with 32-bit userspace — matches
the staging tree's arm64 msm8937go defconfigs.

**Templates found (the big news):**
- **Motorola shipped this SoC family on 4.9**: MSM8917/8937 requalified
  as QM215/SDM429 for Android Go; Moto E6 "surfna" runs Moto's own
  **4.9.112** (mirror: `klabit87/android_kernel_motorola_surfna`,
  branch `surfna_9`). Verified it carries `utag`, `mmi_sys_temp`, and
  `dsi-panel-mot-*` conventions ported to 4.9 → first-party Rosetta
  stone for every Moto-ism we need to translate.
- **Official LineageOS runs this SoC on 4.9 in production**:
  `LineageOS/android_kernel_xiaomi_msm8937`, branches lineage-19.1/20/21
  = **4.9.337** (final 4.9 LTS; EOL 2023-01), same generic
  `msm8937-perf_defconfig` layout. Production proof of Android 12–14-era
  userspace on MSM89x7 + 4.9, and our "mirror official LineageOS"
  reference (the 5-for-5 strategy) for every kernel-config question.
  No lineage-18.1 branch there (they jumped 3.18→4.9 at 19.1).
- `samsung-msm8917` org (and its mirror org `msm8917-dev`): Galaxy
  J-series A11/18.1 on **3.18.124** — corroborates that 18.1 does not
  need 4.9 (they did what we did).

**Gemini research doc fact-check** (`gemini-code-1784568301149.md`,
logged here because we'll reuse the corrected version in the plan):
repo table was directionally right, wrong in detail — "LineageOS
android_kernel_xiaomi_msm8917" doesn't exist (real: `..._msm8937`
above); "samsung-msm8917 = 4.9 + A11" wrong (3.18.124); `msm8917-dev`
is a mirror of the same Samsung org, not a distinct project. Its
"mandatory backports for A11 on 4.9" list is mostly **not applicable**:
memfd_create has been in-kernel since 3.17 (nothing to backport);
binderfs is optional for A11 (we boot 18.1 on 3.18 with static binder
nodes); FSCrypt v2 not required (CAF 4.9 fscrypt v1+ICE is exactly what
msm8937-common's native `fileencryption=ice` fstab targets); FUSE
passthrough is a perf option, not a requirement; cgroup-v2 freezer has
a v1 fallback in A11. The **one real item is eBPF**: on kver ≥ 4.9,
`BpfUtils` demands eBPF (the inverse of our 0006 fix) — but CAF 4.9.227
already contains the code; it's defconfig-enable work, not backporting.
Several of the doc's "required kernel commits" appear fabricated;
treat that section as a checklist of *topics*, not patches.

**Blob-ABI risk (the real gamble, per subsystem):** Wi-Fi low (same
prima family); display/GPU medium (KGSL ABI fairly stable; QM215 shipped
this exact Adreno 308 on 4.9 → Pie blob fallback exists); RIL medium
(rmnet_data in both; Nougat netmgrd vs 4.9 untested); audio medium
(techpack DAI renames); **camera worst** — msm_camera ioctl ABI moved
3.18→4.9; Nougat mm-qcamera daemon + chromatix likely need replacing
with QM215 Pie-era stack (no perry tuning exists) → a 4.9 switch would
probably re-break camera right after 0011 lands. Xiaomi msm8937 devices
(also shipped-on-3.18, old-blob) have working cameras on 4.9 LOS via
newer-BSP camera stacks — encouraging precedent, not a guarantee.

**What we get back on 4.9:** our staging-4.9 reverts become unnecessary
and flip to the tree's native config — msm8937-common 0004 (FBE stays),
0005 (4.9 vold paths correct), 0006 (eBPF prop correct), kernel 0002
(V4L2 uapi native), perry 0009 (FCM level 4 defines 4.9 → VINTF enforce
can stay on). USB configfs replaces the legacy-gadget dance.

**Payoff if it works:** security (LTS merge 4.9.227→4.9.337 is ~110
mechanical releases), and it reopens lineage-19.1/20 as a discussable
target (xiaomi precedent) — the one path that raises the documented
18.1 ceiling. Android 14+ remains off-limits (32-bit blobs).

## 2026-07-20 — Camera: XT1765 sensor ingest — 2 devices enumerate ✅; open still broken

Stock path (user-provided / corrected from handoff placeholder):
`~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml`
(also mirrored under `~/Downloads/…` — prefer the `~/XT1765_…` path).
Build id **NCQS26.69-64-21** — matches CLAUDE.md (final Nougat); reconciles
the earlier NPNS26.118-22-1 / NPQS26.69-64-17 notes (those were live/older
fingerprints, not this dump). Unpacked to
`~/android/stock-perry-NCQS26.69-64-21/`: simg2img sparsechunks, then strip
**131072-byte** `MOT_PIV_FULL256` header (**128 KiB**, not 256) to get ext4;
mount ro at `mnt-system` / `mnt-oem`; extract-files root `tree/`.

**Sensor inventory (stock XML + chromatix XMLs under `mnt-system/etc/camera/`):**
- Back: `s5k4h8` + `<EepromName>s5k4h8</EepromName>` + `<ActuatorName>dw9718s</ActuatorName>`
  / alt `imx219` (+ `dw9718s`, no eeprom node on stock for imx219)
- Front: `mot_ov5695` + `<EepromName>ov5695</EepromName>` / chromatix
  **`l5695fa0`** (NOT the old `l5695f60` typo in pre-0012 proprietary-files)
- Stock actuator libs present: `libactuator_dw9718s.so` (no `*_truly.so` for
  dw9718s). Montana has `libactuator_dw9767_truly.so` (different chip) — naming
  pattern only.
- Extracted via `scripts/extract-perry.sh` + `setup-makefiles.sh`; dropped
  montana s5k3p3/s5k3p8sp; trimmed missing FP/opalum/montana-touch pins.
  Perry touch fw from stock: `synaptics-{ofilm,tianma}-*-perry.tdat`.

**Packaging bugs fixed this session:**
1. Montana `libmmcamera2_sensor_modules.so` hardcodes
   `/vendor/etc/camera/msm8937_mot_camera_conf.xml`. Perry XMLs were on
   `/system/etc/camera/` under the old name → daemon logged
   `Cannot read file ... msm8937_mot_camera_conf.xml` and probed 0 cams.
   Fix: `device.mk` installs perry camera XML as that vendor path + chromatix
   XMLs alongside.
2. With EepromName set, daemon got cameras then **SEGV** in montana
   `eeprom_process+470` (fault addr `0x1`). Tombstone:
   `/data/tombstones/tombstone_29` (2026-07-20 10:05), thread `CAM_sensor`,
   `mm-qcamera-daemon`; nearby memory shows `s5k4h8` + `/dev/v4l-subdev0`.
   Workaround shipped: omit `<EepromName>` nodes (AF/OTP deferred).
3. Kernel still has early `msm_eeprom_platform_probe failed 2192`. On open,
   CCI also logs `GPIO_31 already requested by 2-0028; cannot claim for
   1b0c000.qcom,cci` — suspected related to eeprom/CCI; not chased yet.

**Patch 0012** (`565193c` on perry device tree; xylitol patch file uncommitted
until asked): proprietary-files rewrite + vendor camera conf path +
EepromName omit.

**Live verified after flash:** `dumpsys media.camera` → **2 devices**
(back+front); `vendor.qcamerasvr=running`.

## 2026-07-20 — Camera open blocker refined (docs handoff for research agent)

Post-0012 Snap open of camera 0 fails. Framework: `openSession` `-2` then
`initializeImpl` `-19`. Latest daemon chain (session-stream link **succeeds**;
earlier “Null module / mct_stream_start_link failed” was an intermediate
state, not the current hard fail):

```text
EEPROM MODULE NOT DETECTED! Unable to get module info!
actuator_load_lib: dlopen() failed to load libactuator_dw9718s_truly.so
actuator_load_bin: fopen /data/vendor/camera/actuator_dw9718s_truly.bin failed
module_sensor_actuator_init_calibrate: ACTUATOR_INIT failed
```

We ship `libactuator_dw9718s.so` (stock); open asks for `…_dw9718s_truly.so`,
which **does not exist on XT1765 stock**. `_truly` is a string inside stock
`libmmcamera_s5k4h8_eeprom.so` (module-info vendor suffix). Omitting
EepromName avoids the montana `eeprom_process` SEGV but leaves actuator
init without module info — and something still resolves the actuator name
to `dw9718s_truly`.

Soft noise (not primary): `libmmcamera_sw_tnr.so` missing on both stock and
montana.

**Full attempt log:** earlier `docs/handoff.md` §1a (superseded by 0013
fix below). Staging-4.9 remains parked.

## 2026-07-20 — Camera open/still FIXED (patch 0013)

**Root cause:** With `<EepromName>` omitted, montana
`libmmcamera2_sensor_modules.so` defaults the actuator vendor suffix to
`_truly` and dlopens `libactuator_dw9718s_truly.so`. XT1765 stock only
ships `libactuator_dw9718s.so` (no `_truly` variant; stock’s own
sensor_modules lacks that default). ACTUATOR_INIT failed → framework
`initializeImpl -19`. (Earlier “mct_stream_start_link failed” was an
intermediate state; latest opens already linked the session stream.)

**Fix (0013, perry `8c6bae3`):** `device.mk` PRODUCT_COPY_FILES installs
the same stock `libactuator_dw9718s.so` also as
`libactuator_dw9718s_truly.so`. Comment in `proprietary-files.txt` so
extract does not look for a non-existent stock blob.

**Verified after TWRP oem flash of vendor-raw:**
- Back: Snap open + still (`IMG_20260720_102724.jpg` ~2.5 MB, 3264×2448).
- Front: `mot_ov5695` open + still (`IMG_20260720_102739.jpg`+).
- Soft: first connect per camera often REJECT `-2` then CONNECT succeeds.
- AF still broken without OTP: `msm_actuator_move_focus Invalid-region
  size = 0` / ringing_params NULL — expected until EepromName restored.

**Next camera:** fix montana `eeprom_process` SEGV (or kernel eeprom
probe `2192` / GPIO_31 CCI) before restoring `<EepromName>`. Video
smoke-test. Prefer RIL as next P1 unless continuing AF.
