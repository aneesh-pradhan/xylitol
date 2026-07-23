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
(~699 MB; also `lineage_perry-ota-eng.builder.zip`).

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
`eng.builder.20260719.191216`, pstore accessible.

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

## 2026-07-20 — FM radio FIXED (msm8937-common 0007)

**Symptom (pre-fix):** FM2 launched but `mReceiver.enable` → false after
~9s. AVC spam: `vendor_fm_app` read on `vendor_fm_prop` /
`vendor.hw.fm.init`. Prop unset; no `vendor.fm` init service.

**Root cause (live, Enforcing):**
1. `libqcomfm_jni` (fm-commonsys) always `ctl.start`s `vendor.fm` for
   pronto (not rome/hastings) and polls `vendor.hw.fm.init` until `1`.
   msm8937-common never defined that service. `TARGET_QCOM_NO_FM_FIRMWARE
   := true` only affects `libfmjni`, not commonsys JNI — and
   `fm_qsoc_patches` is not packaged (correct for Iris).
2. QCOM `fm_app.te` never `get_prop`/`set_prop` for `vendor_fm_app` on
   `vendor_fm_prop` (only `system_app.te` had get_prop).
3. `init.qcom.rc` property triggers still listened for legacy
   `hw.fm.init`, not Treble `vendor.hw.fm.init`.

**Hardware path OK before fix:** `/dev/radio0` opens; VIDIOC_QUERYCAP
version `0x3128c` / `201356`; BT soc `pronto`;
`radio_iris_transport` module present. Missing pieces were userspace
bring-up only.

**Fix (0007, msm8937-common `0a23ebb`):**
- `rootdir/bin/init.qti.fm.sh` — NO_FM_FIRMWARE stub: enable
  `fmsmd_set`, `setprop vendor.hw.fm.init 1` (file_contexts already
  labels `init.qti.fm.sh` as `qti_init_shell_exec`).
- `init.qcom.rc`: `service vendor.fm` + triggers on
  `vendor.hw.fm.init={0,1}`.
- `sepolicy/vendor/fm_app.te`: get/set_prop `vendor_fm_app` →
  `vendor_fm_prop`.
- Package script via `rootdir/Android.mk` + `msm8937.mk`.

**Verified after TWRP oem flash of vendor-raw (Enforcing):**
- `init: starting service 'vendor.fm'…` → exit 0 in ~64ms
- `init_success:1 after 0.200000 seconds`
- `mReceiver.enable done, Status :true`
- Props: `vendor.hw.fm.init=1`, mode=normal, version=201356
- Seek/tune works (e.g. 99700 above signal threshold; RDS fields
  present). Wired headset required (antenna). Soft: recurring
  `vendor_fm_app` find on `mediametrics_service` — non-blocking.

## 2026-07-20 — User confirm: FM OK; camera AF still broken (bugreport)

User ear-tested FM and confirmed it works end-to-end. Also re-tested
Snap (open + stills with focus attempts); AF still broken as expected.

**Bugreport (kept local, not in xylitol git):**
`~/android/bugreports/perry/bugreport-perry_retail-RQ3A.211001.001-2026-07-20-13-20-02.zip`
(on-device: `/data/user_de/0/com.android.shell/files/bugreports/` same name;
dumpstate window ~13:20 local).

**FM evidence in bugreport**
- `vendor.fm` start → exit 0; `vendor.hw.fm.init` 0→1 triggers fire.
- Live RDS while listening: `PS: [KMVQ-FM ]`, stereo lock, PI/PTY
  present — confirms RF + audio path, not just enable/tune.

**Camera / AF evidence in same bugreport**
- Open + still OK: `PROFILE_OPEN_CAMERA camera id 0, rc: 0`; JPEGs
  `IMG_20260720_1319{35,38,46,46_1,50,51}.jpg` (~2.3–3.3 MB, 3264×2448).
- AF: **463×** `msm_actuator_move_focus: Invalid-region size = 0,
  ringing_params = NULL` → `move focus failed -14` during the session.
- Daemon: `EEPROM MODULE NOT DETECTED! Unable to get module info!`
  (EepromName still omitted — intentional until montana `eeprom_process`
  SEGV / kernel probe `2192` fixed).

**Next:** RIL (P1). Camera AF = restore EepromName safely.

## 2026-07-20 — Camera OTP/AF cal worked briefly (0014); AF still OPEN research

> **Do not treat AF as fixed.** 0014 got OTP autofocus calibration
> working, then broke preview (next entry). Live tree is **0015**:
> preview/still OK, AF broken again (`Invalid-region`). AF remains
> open research on the Lineage track.

**Pre-0014 (bugreport ~13:20):** 463× `Invalid-region size = 0`;
`EEPROM MODULE NOT DETECTED`; `GPIO_31 already requested by 2-0028`
(sx9310). EepromName omitted to dodge montana `eeprom_process` SEGV.

**Root causes / what 0014 + kernel 0004 changed**
1. **CCI vs sx9310:** base `msm8917-camera.dtsi` claimed cci0+cci1
   (gpio29–32); perry sx9310 IRQ owns gpio31. Kernel **0004**
   (`7c1b60c`): perry sensor DTSI overrides CCI to cci0-only (same
   pattern as hannah/james). GPIO_31 spam gone after boot flash —
   **keep 0004**.
2. **OTP:** restore `<EepromName>s5k4h8</EepromName>` /
   `ov5695` in `msm8917_mot_perry_camera.xml`.
3. **eeprom_process SEGV:** montana `libmmcamera2_sensor_modules.so`
   crashes at `eeprom_process+470` with XT1765 eeprom libs. Stock
   sensor_modules alone needed `libmotimager_utils.so`; then crashed
   in montana `libmotocalibration` (`moto_led_calibration_init`).
   Perry **0014** (`7b163c7`) ships XT1765 stock:
   `sensor_modules`, `eeprom_util`, `motimager_utils`,
   `motocalibration`, `pdaf`, `pdafcamif` (rest of platform stays montana).

**Verified live under 0014 only (OTP cal — later regressed preview)**
- `dumpsys media.camera` → 2 devices; Snap open `PROFILE_OPEN … rc: 0`.
- `s5k4h8_eeprom_autofocus_calibration`: infinity DAC −55..280, macro
  +61..589, initial code 280.
- `Invalid-region` / `EEPROM MODULE NOT DETECTED` / `GPIO_31`: 0.
- Soft: first-open `-2`; no `/persist/camera/ledcal/rear`; API1
  `focus-distances=Infinity` still logged.

## 2026-07-20 — 0014 REGRESSION: black viewfinder / Snap ANR (fixed by 0015)

**Symptom (user):** Snap opens, black viewfinder, then "Camera isn't
responding".

**Root cause:** XT1765 stock `libmmcamera2_sensor_modules.so` (0014) with
montana ISP/iface → `isp_util_map_streams: failed: sensor resolution: 0x0`
→ preview link never comes up → Snap ANR in `setParameters` /
`Camera.release`. OTP/AF cal had worked; stream mapping did not.

**Fix — perry 0015** (`9485df8`): revert to montana `sensor_modules` +
omit `<EepromName>` again. Keep kernel **0004** (CCI cci0-only).

**Verified after vendor flash**
- Montana modules MD5 `b57cabd8…` on device.
- `PROFILE_OPEN … rc: 0`; preview 960×720; stills ~2.5 MB.
- No `resolution: 0x0` / no Snap ANR.
- AF: `Invalid-region` returned (expected).

**Lesson:** do not mix stock `sensor_modules` with montana ISP. AF next
options: full stock camera stack, montana `eeprom_process` shim, or
actuator params from the OTP DAC ranges captured under 0014.

**Next:** RIL (P1) or AF retry without that mix.

## 2026-07-20 — Camera AF = open research; pmOS plan documented

**Lineage camera AF:** remains **open research**, not fixed. Live state is
perry **0015** (montana `sensor_modules`, EepromName omitted): preview +
still work; AF back to `Invalid-region`. Perry **0014** OTP packaging got
AF cal working then broke preview (`sensor resolution: 0x0`) — do not
re-ship that mix. Approaches for a later AF session are listed in
[`handoff.md`](handoff.md) §P1a.

**postmarketOS side quest:** thorough plan written at
[`pmos-perry.md`](pmos-perry.md). Chosen path is mainline generic
`qcom-msm89x7` + lk2nd (not downstream 3.18). Blocker #1: packaged
`linux-postmarketos-qcom-msm89x7` **6.19.5-r0** has **no perry DTB**;
need local carry of [linux#48](https://github.com/msm89x7-mainline/linux/pull/48)
+ [panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6)
before any flash. XT1765 = MSM8917 DTB (wiki MSM8920/XT1766 notes are for
other SKUs). Sacred: never wipe `persist`/`modemst*`; full TWRP backup
before lk2nd.

**Implementation gate:** docs only this pass — no pmbootstrap, no lk2nd
flash, no kernel builds. Phases B–F wait for explicit user approval.
Cross-links: README, handoff §6, CLAUDE.md side-quest blurb.

## 2026-07-20 — pmOS EXECUTION started: phases B done, C building (user-approved)

User approved implementing the pmOS side quest (and set the working
model: research/plans by the planning agent in .md files, execution by
separate agents — hence the new executor runbook
[`pmos-runbook.md`](pmos-runbook.md)).

**Phase B (host) — DONE.** pmbootstrap **3.11.1** at `~/pmos/pmbootstrap`
(symlink `~/bin/pmbootstrap`); non-interactive init via
`~/pmos/init-perry.exp` (expect script). Config
`~/.config/pmbootstrap_v3.cfg`: workdir `~/pmos/work`, channel
**systemd-edge**, device **qcom-msm89x7**, UI console, user `xylitol`,
hostname `perry`. Note: init answered "n" to SSH-key copy — runbook C3
flips `ssh_keys` to True before `install`.

**Phase C (kernel carry) — in progress.** Upstream kernel pkg moved to
**7.0.9-r0** since the research pass (was 6.19.5-r0); still no perry
DTB. Local carry implemented as `pmos/linux-postmarketos-qcom-msm89x7/`
overlay: PR #48's three patches **rebased to v7.0.9-r0** (Makefile typo
fixed) + Tianma 499v1 panel from panel-drivers#6 (generated with
`lmdpdg --dumb-dcs`), pkgrel=1,
`CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V1_TIANMA=m`. Applied via
`scripts/pmos-apply-perry-kernel.sh` (backs up upstream files under
`.xylitol-upstream/`), checksummed. First build attempt (14:58) died on
a transient strict-mode zap failure (`umount chroot_native/proc: target
is busy`); relaunch (15:09) got past zap and is compiling
(`~/pmos/logs/kernel-build.log`). Success criterion:
`boot/dtbs/qcom/msm8917-motorola-perry.dtb` + perry panel .ko in the apk.

**New research locked into the runbook (verified today):**
- Generic install flow (wiki): `pmbootstrap install` →
  `flasher flash_lk2nd` → **verify lk2nd fastboot** → `flasher
  flash_rootfs`; flashing rootfs outside lk2nd can soft-brick.
- **lk2nd upstream supports perry** (devices.md lists Moto E4 perry for
  both MSM8917 and MSM8920); `fastboot boot lk2nd.img` is a documented
  no-flash test → runbook phase D smoke test. lk2nd owns `boot`; real
  boot images then live at 512 KiB offset; stock aboot is untouched, so
  Lineage rollback = reflash Lineage boot.img + TWRP data restore.
- Boot chain for generic port: aboot → lk2nd → **extlinux** from rootfs
  boot dir; `deviceinfo_dtb` glob `qcom/msm8917-*` auto-includes the
  perry DTB. `flash_rootfs` targets **userdata** (kills Android data —
  TWRP data backup is a phase-D hard gate).
- Firmware at runtime via **msm-firmware-loader** (reads the phone's own
  modem/WCNSS partitions) + firmware-qcom-msm89x7 + adreno-a300 — no
  blob shipping needed for Wi-Fi bring-up.
- Perry wiki page is archived but the device runs via the generic port;
  wiki feature matrix (6.19.5): screen/touch/Wi-Fi/BT/audio/3D work,
  camera broken, calls/SMS/data partial. `pstore/console-ramoops` via
  TWRP is the no-boot debug path.

**Gates ahead:** phase D needs TWRP backups (boot + data) + Lineage
boot.img rollback artifact on hand; phase E (first real flash) needs an
explicit user go-ahead. Sacred partitions never in play.

### Addendum: first build FAILED — panel patch used removed kernel API (fixed)

First build (15:09–15:23) died compiling
`panel-motorola-perry-499v1-tianma.c`: `mipi_dsi_dcs_write_seq` is gone
in v7.0.9 (removed in favor of the `mipi_dsi_multi_context` /
`*_multi()` accumulate-errors API). The panel patch had been generated
with `lmdpdg --dumb-dcs` against an older tree. Every *sibling* panel in
`drivers/gpu/drm/panel/msm89x7-generated/` already uses the new style —
mirrored `panel-motorola-montana-r63350-tianma.c` (also Tianma):
`mipi_dsi_dcs_write_seq_multi` + `mipi_dsi_msleep` +
`return dsi_ctx.accum_err`, `container_of_const`,
`devm_drm_panel_alloc`, `drm_connector_helper_get_modes_fixed`, dropped
the `prepared` bool. Init sequence, timings, mode, and
`MIPI_DSI_MODE_VIDEO_HSE` flag kept identical to the generated original.
Patch 0004 regenerated in `pmos/linux-postmarketos-qcom-msm89x7/`,
re-applied + re-checksummed (sums synced back to APKBUILD.overlay),
rebuild launched (`~/pmos/logs/kernel-build-2.log`).

Process lesson: `pmbootstrap build ... | tee log` swallowed the failure
(tee's exit 0) — the "completed" notification was a lie. Use
`set -o pipefail` around pmbootstrap invocations; runbook updated.

### Rebuild SUCCESS — phase C complete (15:32)

`linux-postmarketos-qcom-msm89x7-7.0.9-r1.apk` (26.8 MB) built clean
with the converted panel. Verified contents:
`boot/dtbs/qcom/msm8917-motorola-perry.dtb` (+ `msm8920-` variant) and
`usr/lib/modules/7.0.9-msm89x7/.../panel-motorola-perry-499v1-tianma.ko.zst`.
Runbook C1/C2 checked off. Next for executors: runbook §2 (C3 `ssh_keys`
flip, C4 `pmbootstrap install`, C5 export) — all host-only; then phase D
gates (TWRP backups) before any device contact.

## 2026-07-20 — pmOS Phase C½ done (host image build; no device contact)

Runbook §2 (C3–C5) completed on the Ubuntu build host.

**C3.** Host had an empty `~/.ssh/` (no `*.pub`). Generated
`~/.ssh/id_ed25519` (comment `xylitol@buildhost-perry-pmos`, empty
passphrase) and set `pmbootstrap config ssh_keys True`. Keys are
copied into the *install image* at fill time
(`…/mnt/install/home/xylitol/.ssh/authorized_keys`), not into the
rootfs chroot — so a later `pmbootstrap chroot -r` won't show them;
the flashed userdata image will.

**C4.** `pmbootstrap install --password …` (dummy; noted here only as
**set** — use SSH key). Log: `~/pmos/logs/install.log`. Wall time
~41 min, almost all qemu-aarch64 build of `systemd-edge/systemd`
261.1-r5. Confirmed local kernel:
`(  4/263) Installing linux-postmarketos-qcom-msm89x7 (7.0.9-r1)`.
Rootfs chroot has `boot/dtbs/qcom/msm8917-motorola-perry.dtb` and
`panel-motorola-perry-499v1-tianma.ko.zst`. Combined image
`qcom-msm89x7.img` created at 1314M nominal (actual file ~1.28 GiB).

**C5.** `pmbootstrap export` → `/tmp/postmarketOS-export/`
(`~/pmos/logs/export.log`):

| Artifact | Bytes |
|---|---|
| `lk2nd.img` | 321 552 |
| `qcom-msm89x7.img` | 1 377 828 864 (~1.28 GiB) |
| `vmlinuz` | 9 819 359 |
| `initramfs` | 13 713 848 |
| `dtbs/msm8917-motorola-perry.dtb` | 50 523 |

Broken/unused export symlinks (`boot.img`, split images, recovery
zip) are expected on this flash path — flasher wants `lk2nd` + the
combined rootfs image.

**GATE held:** no USB / no phone. Next is runbook §3 phase D
(Lineage `boot.img` rollback copy, TWRP boot+data backup, battery
≥50%, then `fastboot boot lk2nd.img` smoke). Phase E still needs
explicit user go-ahead.

## 2026-07-20 — pmOS Phase D done (lk2nd smoke; Lineage intact)

Full runbook §3 on XT1765 `ZY224TB8KZ`. Nothing flashed.

**D1.** `~/android/backups/perry/lineage-boot-2026-07-20.img`
(SHA-256 `fe8529e07ff1c5ca9b1691f06efdf2e68505f39e25181169aa88e9a5a418fb84`)
byte-matches the live boot partition for the image size (11 597 824 B).

**D2.** TWRP `twrp backup BD pmos-pre-D-20260720-1656` (boot + data
excl. storage, 273 MB) → host
`~/android/backups/perry/twrp-pmos-pre-D-20260720-1656/`. Also pulled
DCIM/Download/Pictures/`lineage.zip` → `sdcard-pre-D/` (E's
`flash_rootfs` wipes userdata including /sdcard).

**D3.** Battery 99% in TWRP.

**D4–D6.** Stock fastboot `moto-msm8917-BA.34` / `product: perry` →
`fastboot boot lk2nd.img` → lk2nd fastboot. Full dump:
`~/android/backups/perry/lk2nd-getvar-all.txt`. Highlights:

| Key | Value |
|---|---|
| `lk2nd:device` | `perry` ✅ |
| `lk2nd:version` | `22.0-r2-postmarketos` |
| `lk2nd:bootloader` | `0xBA34` |
| `product` | `lk2nd-msm8952` (family) |
| `serialno` | `ZY224TB8KZ` |
| **`lk2nd:panel`** | **`qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`** |

**Panel mismatch:** our C carry + PR #48 DTS hardcode
`motorola,perry-499v1-tianma`. This phone is the **Ofilm** 499
variant. First pmOS boot may have USB net but no display until an
Ofilm panel driver is generated (same `lmdpdg` path as Tianma PR #6)
and the DTS compatible updated (or dual-panel selection added).

**D7.** `fastboot reboot` → Lineage
`eng.builder.20260719.193203` `sys.boot_completed=1`. Reversibility OK.

**GATE for E:** still needs explicit user go-ahead (overwrites `boot` +
`userdata`). Strongly consider Ofilm panel work before or immediately
after E1.

**Research handoff:** full Ofilm tasking for the next agent is in
[`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) (questions, downstream MDSS
paths, deliverable checklist). Handoff opener also in
[`handoff.md`](handoff.md) §“How to start the next session”.

## 2026-07-20 — pmOS Ofilm 499 research DONE + driver implemented (0005/0006)

User confirmed Ofilm question ("is Ofilm real?") and approved
implementation. Full write-up in
[`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) §7; summary:

- **Ofilm = OFILM Group (O-Film Tech, Shenzhen)** — real display-module
  integrator (touch lamination onto LCD cells; ex-Apple supplier).
  Motorola quad-sourced the perry 499 panel: downstream DTS has
  **tianma v0/v1/v2, boe v0/v1, inx v0/v1, ofilm v0**. Our unit's lk2nd
  string matches ofilm v0 exactly — no discrepancy, just multi-sourcing.
- **Upstream has no Ofilm**: linux-panel-drivers PR #6 author explicitly
  didn't know perry had other panel variants. Our detection is new info.
- **lk2nd mechanism** (`lk2nd/device/panel.c`): panel fixup only works
  via an `lk2nd,panel` map node in lk2nd's own device DTS; **lk2nd has
  no perry entry**, so no fixup happens — the mainline DTB's hardcoded
  panel@0 compatible decides. Hence hardcoding Ofilm for this unit.
- **Timing delta**: Ofilm and Tianma 499 share IDENTICAL clock/porches/
  PHY timings; only the DCS init differs — different controller ICs
  (Ofilm = Novatek-style CMD2 `FF AA 55 25`/`F0 55 AA 52 08` incl.
  gamma tables + MADCTL `36 03`, 100 ms display-on delay; Tianma =
  Ilitek ILI9881 `FF 98 81`, 20 ms). Wrong driver ⇒ black screen.
- **Implemented** (hand-converted from
  `dsi-panel-mot-ofilm-499-720p-video-common.dtsi`, multi_context API,
  modeled 1:1 on our Tianma 0004):
  - overlay `0005-drm-panel-add-motorola-perry-Ofilm-499v0-panel.patch`
    (compatible `motorola,perry-499v0-ofilm`)
  - overlay `0006-arm64-dts-qcom-perry-select-Ofilm-499v0-panel.patch`
    (panel@0 tianma→ofilm, this unit only; 0005 stays upstreamable)
  - `pmos-apply-perry-kernel.sh` + `APKBUILD.overlay` (pkgrel=2,
    `CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V0_OFILM=m`, Tianma kept)
- All 6 patches apply clean in pmbootstrap build (verified in log).

Phase E remains gated. Next: kernel apk rebuild → non-flash
`fastboot boot` smoke to check Ofilm first-light.

## 2026-07-20 — pmOS Ofilm smoke attempt (D¾): kernel builds, fastboot-boot chain fails pre-initramfs

7.0.9-r2 built + installed + exported. Verified in the apk:
`panel-motorola-perry-499v0-ofilm.ko.zst` present; perry DTB contains
`motorola,perry-499v0-ofilm` (no tianma string).

Non-flash smoke via stock aboot → `fastboot boot lk2nd.img` → lk2nd
fastboot → `fastboot boot <crafted boot.img>`:

- `pmbootstrap flasher boot` fails outright — qcom-msm89x7 is extlinux-
  based; no boot.img is generated (deviceinfo has no generate_bootimg).
- Hand-crafted header-v2 image (`--dtb` field) → lk2nd `dtb not found`
  (lk2nd doesn't use the v2 dtb field).
- Gzip kernel + appended perry DTB, header v0, arm32-style offsets
  (`kernel_offset 0x8000, ramdisk 0x01000000`) → lk2nd jumps
  (USB drops) but device watchdog-resets to Lineage; suspected
  decompressed-kernel/ramdisk overlap.
- Same with arm64 offsets (`kernel 0x00080000, ramdisk 0x02000000,
  tags 0x01e00000`) → same result: USB drop, no pmOS gadget
  (18d1:d001) within 2 min, reset back to Lineage.
- pstore/console-ramoops after reset contains only downstream 3.18
  logs — mainline dies before any console/ramoops (and mainline lacks
  the downstream ramoops node), so no crash log obtainable remotely.
- **Diagnosis: failure is pre-initramfs (USB gadget never appears), so
  it says NOTHING about the Ofilm panel driver.** It's a
  lk2nd-fastboot-boot arm64 load-layout issue. The flashed Phase E path
  does not use this mechanism at all (extlinux + `fdtdir` — lk2nd loads
  `/msm8917-motorola-perry.dtb` as a file), so E is unaffected.

Device state after: Lineage boots fine (verified repeatedly). Nothing
flashed. Crafted images in session scratchpad only (not in git).

**Next options:** (a) user observes the screen during one more
fastboot-boot retry (did lk2nd splash/kernel logo appear at all?);
(b) skip the smoke and treat Phase E (flash, user-gated) as the real
Ofilm first-light test — extlinux path avoids the boot.img quirks;
(c) debug lk2nd fastboot-boot layout further (low value vs. E).

Image note: rootfs regenerated with throwaway user password `xylitol`
(SSH key auth is the intended login; rootfs not flashed anywhere yet).

## 2026-07-20 — Ofilm smoke retry with user observing: confirms pre-initramfs death

Third layout variant (v0c: kernel 0x00080000, ramdisk 0x04000000, tags
0x03e00000 — well clear of kernel BSS) behaved identically. **User
observed the screen:** lk2nd screen → display off at kernel handoff →
display back on with Moto aboot's "N/A" (unlocked-warning region, i.e.
full SoC reset) → LineageOS splash.

Interpretation:
- Display-off at handoff is EXPECTED even for a good boot: DTS ships
  `framebuffer0` (simple-framebuffer) `status = "disabled"` and the
  panel driver is an initramfs module — first light can only happen at
  initramfs splash time.
- The reset + no USB gadget ⇒ mainline kernel dies before initramfs on
  the lk2nd `fastboot boot` path, regardless of bootimg layout. Likely
  in the lk2nd→aarch64 entry itself (32-bit lk chaining a 64-bit
  kernel), which the packaged extlinux flow exercises differently.
- **Ofilm panel driver: still untested, and un-refuted.** Smoke via
  fastboot-boot is a dead end for this device; panel first-light will
  come from Phase E (extlinux; user-gated) or from debugging lk2nd's
  fastboot-boot arm64 path (low value).

Device: Lineage intact (user-witnessed splash; adb `device` state).
Nothing flashed at any point today.

## 2026-07-20 — pmOS BOOTS to userspace (Blocker B cleared); WiFi fixed

**Headline: Phase E Blocker B is dead.** The kernel that last session was
"blind & mute" (see the Phase E handoff section) now boots all the way to a
full postmarketOS edge userspace — `7.0.9-msm89x7`, **aarch64** — with USB-net
+ SSH. User reported the phone visibly reaching pmOS and a WCNSS NV error on
screen; this session confirmed the whole stack over USB.

**USB access.** The pmOS gadget enumerates as CDC-NCM (`DRIVER=cdc_ncm`,
`PRODUCT=18d1/d001` — lsusb mislabels it "Nexus 4 (fastboot)", but
`fastboot devices` is empty; it is NOT fastboot). Host never gets a DHCP
lease, so assign it by hand:
```
sudo ip addr add 172.16.42.2/24 dev <usb-iface>   # host side
ping 172.16.42.1                                    # device side
ssh xylitol@172.16.42.1                              # key auth; sudo pw xylitol
```
The USB link **auto-suspends / re-enumerates** frequently, which wipes the
host static IP — re-add it before each reconnect. Wrap all ssh/fastboot in
`timeout` and retry.

**WiFi root cause — missing NV blob (self-inflicted by our DTS).** Our perry
DTS (`pmos/linux-postmarketos-qcom-msm89x7/0003-*.patch`) sets
`&wcnss_ctrl { firmware-name =
"qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin"; }`. That directory does
not exist in the stock pmOS rootfs (it ships NV blobs for sibling MSM8937
Motos **cedric** and **montana** under `qcom/msm8937/motorola/…`, but not
perry). So `qcom_wcnss_ctrl` fails the NV load with `-2` (ENOENT) →
`wcn36xx` aborts → no `wlan0` (device had only `lo` + `usb0`).

**Fix.** Drop perry's own NV at the DTS path. Perry's authoritative NV is the
one the Lineage build packages from the (montana-shared) vendor blobs:
`out/target/product/perry/vendor/etc/wifi/WCNSS_qcom_wlan_nv.bin`, md5
`4f88c4c5435d0d80c5e1c9bbe360a57e`, 31723 B. (Distinct from montana's
`b1d83c4c…` and cedric's `a61d05a2…`, though all three are 31723 B — the perry
NV differs in RF cal/regulatory, not size.) Copied to a stable local home
(`~/android/backups/perry/WCNSS_qcom_wlan_nv.perry.bin`, since `out/` is wiped
on clean builds) and installed on-device via
`scripts/pmos-install-wcnss-nv.sh`. **NV blob is proprietary — never
committed** (`.gitignore` blocks `*.bin`).

**Verified (cold boot, perry NV):** no `Failed to load nv` in dmesg; `wcn36xx`
loads `firmware WLAN version 'WCN v2.0 RadioPhy vIris_TSMC_4.0 with 48MHz XO'`;
`wlan0` created; scan saw **51 APs on 2.4 + 5 GHz**; associated to a WPA2 AP,
DHCP lease + `ping 1.1.1.1` ~20 ms; NetworkManager **auto-reconnects on boot**.

**Two gotchas learned:**
- **wcn36xx MAC is device-derived, not from the NV.** It came up
  `02:00:02:4b:07:1b` — last three bytes match perry's lk2nd serial
  `24b071b`. So the NV swap doesn't change the MAC; installing perry's own NV
  is about RF cal/regulatory correctness, not identity.
- **Do NOT restart the WCNSS remoteproc by hand to pick up the NV.** A manual
  `echo stop/start > /sys/class/remoteproc/remoteproc1/state` wedged the WCNSS
  SMD channel (`wcn36xx: ERROR Timeout! No SMD response ... 10000ms`,
  `hal_stop failed`), tearing `wlan0` down. Graceful `reboot` then hangs on the
  wedged WCNSS during shutdown (uptime never resets). Recover with a
  kernel-level reboot: `echo 1 > /proc/sys/kernel/sysrq; sync;
  echo b > /proc/sysrq-trigger`. A clean cold boot brings WiFi up reliably.

**Durability — solved with a download-based pmaport.** The runtime installer
(`scripts/pmos-install-wcnss-nv.sh`) writes to the rootfs (survives reboot)
but a `pmbootstrap install` regen wipes it. The durable fix is a pmaport that
bakes the NV into the rootfs at build time:
`pmos/firmware-motorola-perry-nv/` + `scripts/pmos-apply-perry-firmware.sh`
(`pmbootstrap build firmware-motorola-perry-nv` →
`install --add firmware-motorola-perry-nv`). Named `-nv` deliberately:
pmaports already ships an archived `firmware-motorola-perry` (parent +
`-wcnss` subpackage) that installs the NV to
`/lib/firmware/postmarketos/wlan/prima/` — the downstream layout, **not** the
`qcom/msm8917/motorola/perry/` path our mainline DTS (PR #48) requests — so it
does not satisfy wcn36xx and a same-named package would also collide in the
aports scan.

**Blob source (user OK'd outside sources — device is Moto/Qcom-abandoned):**
the APKBUILD downloads the *same community mirror tarball pmaports itself pins*
(`lastramses/firmware-motorola-perry` @ `813155d3`) — verified byte-for-byte
against pmaports' `de37ff72…` sha512. So no blob is committed to xylitol and
none is hand-supplied: anyone can reproduce Wi-Fi with no extraction. Build-
validated 2026-07-20: the apk installs
`lib/firmware/qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin`.

**NV provenance caveat:** the mirror NV (md5 `3076c1a0…`) is a community perry
extract and differs from *this* XT1765 T-Mobile unit's own stock/Lineage NV
(`4f88c4c5…`, saved at `~/android/backups/perry/WCNSS_qcom_wlan_nv.perry.bin`).
Both are valid perry NVs; the delta is RF/regulatory cal only — the wcn36xx MAC
is SoC-derived (`02:00:02:4b:07:1b`, tail matches lk2nd serial `24b071b`), not
from the NV. For a device-exact durable NV, drop the stock blob into the aport
dir, point `source=` at it, and re-checksum (documented in `docs/pmos.md`
step 6); the runtime installer already uses the device-exact blob.

### Ofilm 499v0 panel — first-light CONFIRMED (user-witnessed)

The panel-research brief ([`pmos-ofilm-panel.md`](pmos-ofilm-panel.md)) had the
Ofilm 499v0 DRM driver (overlay 0005 driver + 0006 DTS select) as "untested,
un-refuted" — the fastboot-boot smoke path was a dead end for this device. This
session confirmed it on the booted rootfs. Device-side evidence:
- DTS-selected panel `compatible: motorola,perry-499v0-ofilm` (Ofilm, **not**
  Tianma); module `panel_motorola_perry_499v0_ofilm` loaded.
- `card0-DSI-1` **connected + enabled**, mode **720×1280**; `fb0` 720×1280×32;
  `Console: switching to colour frame buffer device 90x80`; `agetty` on the
  console; backlight `/sys/class/backlight/backlight` `2048/4095`, `bl_power=0`.
- msm/DPU stack bound: `msm_dpu 1a01000.display-controller: bound 1a94000.dsi`,
  `dpu hardware revision 0x100f0000`, `Initialized msm 1.13.0`.

Visible test (fb fill white → `/dev/urandom` static → backlight blink 3×):
**user confirmed** seeing the random static rendered, the persistent
`perry login:` tty text, and the backlight blinking. So the full
DPU→DSI→Ofilm-panel→backlight chain drives the glass. **Panel = WORKING.**
(One cosmetic quirk noted: initramfs splash times out —
`[pmOS-rd]: ERROR: /dev/fb0 did not appear after waiting 10 seconds!` — because
fb0 only appears at ~27 s when the DPU/DSI binds, past the 10 s initramfs
wait; the console fb comes up fine afterward. Non-blocking; a splash-timing
nicety for later.)

## 2026-07-20 — pmOS feature-matrix walk (SSH)

Walked the wiki-claimed feature matrix over USB-net SSH on the live
`7.0.9-msm89x7` edge install (XT1765 / perry). Also: squash-merged PR #2
(`firmware-motorola-perry-nv`), closed Cursor cloud draft PR #1, deleted
`cursor/setup-dev-environment-ec44`, and did a `main`→`main1`→`main` default-
branch rename so GitHub's contributors list drops `cursoragent`.

### Results

| Feature | Result | Evidence |
|---|---|---|
| Wi-Fi | **Works** | `wlan0` associated (WPA2), DHCP, internet |
| USB-net / SSH | **Works** | CDC-NCM @ `172.16.42.1`; host self-assigns `.2` |
| Display (Ofilm) | **Works** | `card0-DSI-1` connected 720×1280, backlight 2048 |
| Touch | **Works** | `Synaptics S3603R` input present |
| 3D / GPU | **Works** (bound) | Adreno via msm DRM; `card0` + `renderD128`; a300 fw loaded |
| Battery / charge | **Works** | `qcom-battery` 99%, USB online via `qcom-smbchg-usb` |
| Bluetooth | **Works** | `hci0` up (`btqcomsmd`); after `apk add bluez`, scan saw many LE devices (EDIFIER BLE, etc.). Address `02:00:02:4B:07:1A` |
| Accel | **Works** | IIO `bma253` on `i2c-sensors` (`imu@18`); raw xyz changing |
| Prox / ALS | **Missing** | No IIO/input nodes; only PMIC ADCs + bma253 |
| GPS | **Not present** | No gnss module/device; reserved-mem `gps` region only |
| Vibrator | **Missing** | No `/sys/class/leds/vibrator`, no DT vib/haptic node, no FF device |
| Audio | **Partial / broken UX** | Card `motorola-perry` + WCD/APR/Q6 up; PCM nodes exist. **No UCM for perry** (`alsaucm` → `-2`); sibling UCMs are montana/hannah/potter only. `speaker-test` → `-22` / "no backend DAIs enabled for MultiMedia1". Needs a perry (or msm89x7) UCM profile |
| Cameras | **Broken** (as wiki) | `camss@1b00000` + `cci@1b0c000` both `status=disabled` in DT. `/dev/video0/1` are Venus enc/dec only — no CAMSS |
| Modem | **Partial** | `/dev/wwan0at0` answers `AT`/`ATI` (Motorola Mobility / MPSS.JO.3.0). `AT+CPIN?` → `SIM not inserted` (no SIM in this test). No ModemManager package |

### Side effect — `apk add` rewrote extlinux back to `fdtdir /`

Installing `bluez`/`alsa-utils`/`v4l-utils` triggered `boot-deploy` /
`mkinitfs`, which regenerated `/boot/extlinux/extlinux.conf` with
`fdtdir /` (Blocker A). **Live `/boot` was immediately patched back** to
`fdt /msm8917-motorola-perry.dtb`. This is another real-world proof that
the durable fix (perry lk2nd device node, or boot-deploy override) is
urgent — any package that touches the kernel/initramfs will brick the
next reboot until `fdt` is restored by hand.

Also: the same trigger reinstalled the perry DTB at stock size (50523 B),
so any prior Solution-2 DTB edits (`fb=okay` / `usb=peripheral`) on the
live boot partition are gone. USB-net and DRM console still work without
them on this already-booted system.

## 2026-07-20 — Durable extlinux `fdt` via `/etc/deviceinfo`

**Root cause of Blocker A recurring:** `device-qcom-msm89x7` sets
`deviceinfo_dtb` to a multi-SoC glob (`qcom/msm8917-* …`). boot-deploy's
`create_extlinux_config` then emits `fdtdir /` whenever `find_all_dtbs`
returns >1. lk2nd has no perry device node → `lk2nd_device_get_dtb_hints()`
returns NULL → boot aborts. Any `apk` that triggers `mkinitfs` regenerates
extlinux and undoes a hand-edit (hit this during the feature-matrix
`apk add bluez`).

**Fix:** boot-deploy sources `/etc/deviceinfo` *after* the package
deviceinfo. A one-line override:
```
deviceinfo_dtb="qcom/msm8917-motorola-perry"
```
makes `find_all_dtbs` return exactly one path →
`fdt /msm8917-motorola-perry.dtb`. Verified live: delete extlinux.conf,
`mkinitfs`, result is `fdt` not `fdtdir`.

Shipped as local pmaport `pmos/deviceinfo-motorola-perry/` (+ apply /
runtime install scripts). Build-validated; installed on the live rootfs via
`apk add --allow-untrusted`. This is the pragmatic durable fix; a perry
lk2nd device node remains the "proper" upstream fix (also unlocks panel
auto-select and clears "Unknown (FIXME!)").

## 2026-07-20 — Validate durable fdt fix (runbook `pmos-fdt-fix-runbook.md`)

Executor ran [`docs/pmos-fdt-fix-runbook.md`](pmos-fdt-fix-runbook.md) after
maintainer go-ahead past the STOP GATE.

### Steps 0–5 (pre-reboot) — PASS

- **Step 0:** `deviceinfo_dtb="qcom/msm8917-motorola-perry"`; file sha512
  matches APKBUILD (`9901e23e…`).
- **Step 1:** USB-net up (`enxa2746e711a5e` → `172.16.42.1` ping OK).
- **Step 2 BEFORE:** already `fdt /msm8917-motorola-perry.dtb`;
  `/etc/deviceinfo` present (from earlier live install of the pmaport).
- **Step 3:** `pmos-install-perry-deviceinfo.sh` → regenerated extlinux with
  `fdt /msm8917-motorola-perry.dtb` (no `fdtdir`).
- **Step 4:** `dtb_count=1`; flat `/boot/msm8917-motorola-perry.dtb` present.
- **Step 5:** `apk add tree` (triggers mkinitfs/boot-deploy) → still
  `fdt /msm8917-motorola-perry.dtb`; same after `apk del tree`. **The exact
  regen path that previously bricked us no longer flips to `fdtdir`.**

### Step 6 — reboot confidence check

- **Issued** `sysrq-trigger b` over SSH (pre-uptime 5175 s).
- Device returned on USB-net ~45 s later (post-uptime **45 s**).
- Post-boot: still `fdt /msm8917-motorola-perry.dtb`; `/etc/deviceinfo`
  present; `deviceinfo-motorola-perry` apk installed. **STEP 6 PASS** —
  cold boot through lk2nd + explicit `fdt` succeeds.

### Step 7 — durable build-time path

- `./scripts/pmos-apply-perry-deviceinfo.sh` → pmaports copy updated.
- `pmbootstrap build deviceinfo-motorola-perry` → **up to date** (exit 0);
  **no `checksum` step needed** (sha512 already matched).
- Apk at `~/pmos/work/packages/edge/x86_64/deviceinfo-motorola-perry-1-r0.apk`
  contains `etc/deviceinfo`. **STEP 7 PASS.**
  (Did **not** run full `pmbootstrap install` reflash — out of scope.)

### Verdict

Durable `fdt` fix is **validated end-to-end**: apk-triggered regen keeps
`fdt`, and a real cold reboot through lk2nd boots pmOS with the same
extlinux line. Runtime path (`pmos-install-perry-deviceinfo.sh`) and
build-time path (`deviceinfo-motorola-perry` pmaport) both good.

## 2026-07-20 — Retire Solution-2 DTB hacks (fb=okay / usb=peripheral)

Gap #3 from [`pmos-fdt-brick-fix-plan.md`](pmos-fdt-brick-fix-plan.md) was
"make the Solution-2 DTB edits (`fb=okay`, `usb=peripheral`) durable in the
overlay, since they're lost on every `pmbootstrap install`/regen." On
investigation the correct action is the opposite: **retire both — no overlay
change.**

**Evidence — sibling DTBs on this exact kernel** (`dtc -I dtb` on the rootfs
`/boot/dtbs/qcom/*.dtb`, `linux-postmarketos-qcom-msm89x7` 7.0.9):

| Board | SoC | `framebuffer@90001000` | `dr_mode` |
|---|---|---|---|
| nora | msm8917 | `status="disabled"` | `otg` |
| montana | msm8937 | `status="disabled"` | `otg` |
| cedric | msm8937 | `status="disabled"` | `otg` |
| **perry** (ours) | msm8917 | `status="disabled"` | `otg` |

Perry's committed overlay (0003) already matches the whole family.

**Why fb=okay is wrong to fold in:** every sibling keeps the simple-framebuffer
*disabled* and relies on the real msm DPU/DSI DRM driver for the console (perry:
Ofilm 499v0, up ~27 s). We have **no** positive on-device evidence that enabling
simplefb works on perry (Blocker B was cleared with fb *disabled*; the live
Solution-2 edit was lost on regen and the device still boots). Enabling it needs
a kernel rebuild + reflash to test and risks a garbage splash (stale/absent
lk2nd cont-splash at 0x90001000) or clock/GDSC handover contention with the real
DPU — a family-diverging change for a purely cosmetic, non-blocking gain. If
early splash is ever wanted, the low-risk path is the initramfs splash-timeout
bump (handoff to-do #6), not simplefb.

**Why usb=peripheral is wrong to fold in:** `dr_mode="otg"` is the family
convention and USB-net enumerates fine on the booted device with `otg`.
`peripheral` was a Blocker-B bring-up hack (back when a hang vs. a silent gadget
were indistinguishable); it is unnecessary now and would break OTG host mode.
The upstream-correct fix, only if gadget enumeration ever regresses, is
extcon/charger role detection (`pmi8950_smbcharger`, `usb_id` GPIO 97) — never
pinning `peripheral`.

**Net:** the recurring "Solution-2 edits keep getting wiped on regen" worry is
moot — there was nothing worth making durable. Overlay unchanged; handoff E-6
and to-do #4 updated to reflect the decision.

## 2026-07-20 — lk2nd perry device node (built + binary-verified; flash pending)

Handoff to-do #5. Perry (XT1765/MSM8917) had no lk2nd device node, so lk2nd
`lk2nd-msm8952` v22.0 showed "Unknown (FIXME!)", logged `Failed to find matching
lk2nd device node: -1`, and returned NULL from `lk2nd_device_get_dtb_hints()` so
`fdtdir /` could not resolve (the Blocker-A root cause).

**Research (lk2nd tag 22.0 source):** device nodes live in
`lk2nd/device/dts/<soc>/`; perry's family is the `msm8952` build.
`msm8917-mtp.dts` already defines perry's MSM8917 siblings **nora** and
**hannah** as `&lk2nd` children — perry was simply missing. `device/2nd/match.c`
matches `lk2nd,match-device` against `lk2nd_dev.device` (already `perry` at
runtime, per `fastboot getvar lk2nd:device`); `device/device.c` reads `model`
(clears FIXME) and `lk2nd,dtb-files` (feeds the `fdtdir` resolver via
`boot/extlinux.c`). No board-id work needed (generic MTP dtb is what loads;
device-level match does the rest); no panel node (single Ofilm DTB), mirroring
the jeter template.

**Change:** `pmos/lk2nd/0001-device-add-motorola-perry-msm8917-node.patch` adds

    motorola-perry {
        model = "Motorola Moto E4 (perry) (MSM8917)";
        compatible = "motorola,perry";
        lk2nd,match-device = "perry";
        lk2nd,dtb-files = "msm8917-motorola-perry";
    };

Carried + built via `scripts/pmos-apply-lk2nd-perry.sh` (injects the patch into
the local pmaports `main/lk2nd` aport, bumps `pkgrel` 2→3 for a version tell,
re-checksums).

**Build validation (host, no device):** `pmbootstrap build lk2nd` exit 0
(cross-native, arm-none-eabi). `strings` on the built
`lk2nd-msm8952-22.0-r3` `lk2nd.img` shows `Motorola Moto E4 (perry) (MSM8917)`,
`motorola,perry`, `perry`, `msm8917-motorola-perry`, and `22.0-r3-postmarketos`;
siblings nora/hannah intact; the shipped r2 apk had **zero** perry references
(control). So the node compiles and is embedded.

**Pending (device-side, gated):** flash lk2nd r3 to `boot` + verify
`lk2nd:version=22.0-r3-postmarketos`, model no longer FIXME, `-1` log line gone,
normal boot intact. Runbook: [`pmos-lk2nd-perry-node.md`](pmos-lk2nd-perry-node.md).
Complementary to the deviceinfo `fdt` pin (both make boot durable; independent).
Note: local pmaports `main/lk2nd` aport is now dirty (patch + pkgrel=3) — the
xylitol patch+script reproduce it.

### 2026-07-20 (same day) — lk2nd perry node FLASHED + VALIDATED

Flashed the r3 build (above) from stock aboot fastboot (`ZY224TB8KZ`,
`product: perry`) via `pmbootstrap flasher flash_lk2nd` — `Sending 'boot'
(314 KB) OKAY`, `Writing 'boot' OKAY` ("Image not signed or corrupt" = normal
unlocked-Moto warning). Rootfs chroot confirmed `lk2nd-msm8952 V:22.0-r3` and
the flashed `lk2nd.img` carried the perry strings.

Runtime validation (lk2nd fastboot serial `24b071b`):
- `lk2nd:version` = `22.0-r3-postmarketos`, `product` = `lk2nd-msm8952`.
- `fastboot oem log`: **`Detected device: Motorola Moto E4 (perry) (MSM8917)
  (compatible: motorola,perry)`** — node matched; the prior
  `Failed to find matching lk2nd device node: -1` / "Unknown (FIXME!)" is gone.
  Log also shows `androidboot.device=perry`, panel
  `qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`, `androidboot.hardware.sku=XT1765`.
- `fastboot continue` → pmOS booted through the new lk2nd: USB-net came up,
  `ssh xylitol@172.16.42.1` → `Linux 7.0.9-msm89x7`, `up 0 min`, `wlan0` present.
  **No boot regression.**

So the device node fix is complete on hardware: identity fixed and `fdtdir`
now resolves natively (belt-and-suspenders with the deviceinfo `fdt` pin — either
alone boots). Only `boot` was written; sacred `persist`/`modemst*` untouched.

### 2026-07-20 — lk2nd perry node is already upstream (no PR)

Before prepping an upstream PR, checked lk2nd `main`: perry was **already added**
by `d9ce4e70` (2026-04-09, "dts: msm8917 & msm8920: add support for the Motorola
Moto E4 (perry)"). The upstream node is **byte-for-byte identical** to the one
derived here (model/compatible/match-device/dtb-files) — independent, same
result, which corroborates correctness; upstream also did the msm8920 variant.
It is just not in the released `22.0` tag pmaports pins (`main` ~96 commits
ahead). So **no PR** — `pmos/lk2nd/0001-*` is a temporary backport; drop it (and
the pkgrel bump) when pmaports bumps lk2nd past `d9ce4e70`.

## 2026-07-20 — pmOS audio: perry ALSA UCM profile (mute → Speaker + Mic working)

**Strategic note:** user reprioritised — **pmOS is now the primary goal**, not a
side quest ("Prioritize pmOS entirely… this is our ultimate goal. Let's focus
on the big deliverables for a proper pmOS end-user experience; audio UCM would
be the next step"). Android/Lineage RIL is deferred. Docs/side-quest framing
updated to match (see handoff headline).

**Symptom (from handoff):** card `motorola-perry` (Q6/msm8x16-wcd) enumerated,
but `alsaucm` → `-2` and `speaker-test` → "no backend DAIs" — the phone was
mute.

**Root cause:** no UCM profile for perry. UCM2 matches by
`conf.d/${CardDriver}/${CardDriver}.conf`; perry's `${CardDriver}` is
`motorola-perry` (DTS sound node sets `model = "motorola-perry"`, no
`driver_name`, so the ALSA ctl driver string falls back to the card name — 14
chars, fits the 16-byte field; confirmed via the driver field in
`/proc/asound/cards`). pmaports/`alsa-ucm-conf` ships montana/hannah/potter but
**not perry**, so nothing routed the MultiMedia front-ends to a backend DAI.

**Fix — author `conf.d/motorola-perry/motorola-perry.conf`.** perry uses the
internal **msm8x16-wcd** codec (its `ADC1-3 Volume`, `RX1-3 Digital Volume`,
`EAR_S`, `HPHL/R`, `SPK DAC Switch`, `DEC1/2 MUX` are the tell — same as MSM8917
sibling montana and the potter/G5-Plus template). Chose the **potter HiFi verb**
(`/Motorola/potter/HiFi.conf`) over montana's (montana → `Xiaomi/vince/HiFi.conf`
has **no Speaker device** — vince uses an external TAS2557 amp) because perry
exposes `SPK DAC Switch` (internal-codec speaker). Before adopting, verified
**every** cset in potter/HiFi.conf + the `/codecs/msm8953-wcd/*` sequences
exists on perry's card (`CIC1/RDAC2/ADC2/DEC1 MUX`, `SPK DAC Switch`, `RX*
MIX1 INP1`, `RX1-3 Digital Volume`, `ADC1-3 Volume` — all OK; only unreferenced
`DEC1/2 Volume` absent). BootSequence mirrors hannah (RX1/2/3=84, ADC1/2/3=6).

**Validated (over SSH, this session):**
- `alsaucm -c motorola-perry list _verbs` → `0: HiFi` (rc 0). Devices:
  Speaker/Earpiece/Headphones/Mic1/Mic2/Headset.
- `alsaucm set _verb HiFi set _enadev Speaker` → `PRI_MI2S_RX Audio Mixer
  MultiMedia1` = **on**, `SPK DAC Switch` = **on** (backend DAI now connects).
- `aplay -D hw:0,0` a 48 kHz tone → streams cleanly, **zero** ASoC/DAI/XRUN
  kernel errors (the old "no backend DAIs" is gone). Repeatable.
- **WirePlumber** then exposes a **`Built-in Audio Speaker playback`** sink +
  **`Primary Microphone`** source (names come from potter/HiFi device Comments).

**Two pre-existing pmOS stability bugs found+fixed while validating (they made
the audio nodes flap, not the UCM):**
1. **WirePlumber libcamera-monitor crash loop.** perry's cameras are off in the
   DT; the WP libcamera monitor initialises libcamera then dies on the
   half-present camera → new session-manager instance every ~20 s. Disabled via
   `/etc/wireplumber/wireplumber.conf.d/50-perry-disable-libcamera.conf`
   (`monitor.libcamera = disabled`; video-capture is a *wants* dep of the main
   profile, so safe). WP 0.5.15.
2. **No systemd linger.** In headless SSH bring-up (no phosh session) the user
   systemd manager — and thus pipewire/wireplumber — is torn down whenever the
   last login session closes; each short SSH command churned it (session ids
   climbing 12→22→…, graceful "Stopping", no signal). `loginctl enable-linger xylitol` → WP stays `active` across disconnect+reconnect, sink/source persist.
   A real phone UI session would keep it alive; linger is a runtime step (not
   packaged).

**Durable artifacts (in xylitol):**
- pmaport `pmos/alsa-ucm-motorola-perry/` (APKBUILD + `motorola-perry.conf` +
  `50-perry-disable-libcamera.conf`; `depends="alsa-ucm-conf"`). Install-durable.
- `scripts/pmos-apply-perry-ucm.sh` — drop the aport into the pmaports tree
  (`pmbootstrap build … && install --add alsa-ucm-motorola-perry`).
- `scripts/pmos-install-perry-ucm.sh` — runtime installer over SSH (idempotent;
  copies both configs, enables linger, restarts WP). Ran green end-to-end.
- On-device file == repo (sha512 match).

**Audible output USER-CONFIRMED (2026-07-20):** played a beep+rising-sweep clip
out the speaker; user reply "Audio works cleanly. I can confirm the speaker is
live and well." So the full path (app/ALSA → UCM → msm8x16-wcd → speaker) is
verified end-to-end, audibly. **Next:**
earpiece/headset-jack routing under a UI (phosh), call audio (with modem), and
per-route volume defaults. Modem/ModemManager is the next big pmOS deliverable.

## 2026-07-20 — pmOS Phosh mobile UI up (user-confirmed SUCCESS)

**Deliverable: perry boots to a usable touch mobile shell.** No SIM on hand, so
the modem/ModemManager item was skipped; user chose "a good working mobile UI"
instead. Installed **Phosh** (the GNOME/GTK phone shell). User confirmed success
on the glass.

**Starting state:** the rootfs was a **UI=none console install** (booted to
`perry login:` tty, no shell). Substrate already good: `mesa-dri-gallium`
installed, `/dev/dri/card0` + `renderD128` present (freedreno/Adreno 308), 1.4 GB
RAM free, Adreno quirks shipped, touch + panel already working.

**What was done (all on the running device over SSH — reversible, no flash):**
1. `apk add postmarketos-ui-phosh` (v31-r0) — 533 pkgs, ~1.3 GB footprint: phosh,
   phoc (wlroots compositor), phrog (Rust greetd greeter), phosh-osk-stevia OSK,
   xdg-desktop-portal-phosh, mobile apps. Run as a **transient `systemd-run`
   unit** (`--unit=phosh-install`) because a plain `nohup … &` got reaped on SSH
   session teardown (this device aggressively kills session procs — same reason
   we needed linger for audio). systemd-run survives session churn.
2. `systemctl set-default graphical.target` (greetd.service ships **enabled**).
   greetd is configured via `/etc/phrog/greetd-config.toml` →
   `/usr/libexec/phrog-greetd-session` (vt7). pmOS uses **phrog**, not phog.
3. **Reboot** for a clean console→compositor handover (a live `systemctl restart
   greetd` on the running multi-user system hit `connector DSI-1: Atomic commit
   failed: Resource busy` — the kernel DRM fbcon on the active VT still owned the
   panel; a real graphical boot avoids that race).

**Clean-boot result (validated in journal + user-confirmed visually):**
- `graphical.target`, greetd active, `gnome-session --session=phosh` running as
  `xylitol`, phosh shell (pid) live.
- phoc: **`Modesetting with 720x1280 @ 60.000 Hz`** on DSI-1; EGL up on
  **GBM/mesa** (`EGL_MESA_platform_gbm`) → Adreno 308 GL accel working.
- **User: "PmOS is a success"** — boots to the Phosh mobile UI.

**Known non-blocker:** intermittent `phoc … connector DSI-1: Atomic commit
failed: Resource busy` persists post-modeset (~9 in 2.5 min vs ~9000 frames,
~0.1%, bursts during heavy redraw). phoc retries; user reports success, so
benign for now. **If it ever manifests as freeze/glitch:** force phoc off the
atomic KMS path with `WLR_DRM_NO_ATOMIC=1` (drop-in env for the phoc/greetd
session) — the standard wlroots-on-Qualcomm workaround. Not applied (unneeded).

**DURABILITY — DONE 2026-07-21:** clean Phosh install image built and published.
See porting-log entry below ("Durable Phosh image + GitHub Release").

**Cumulative pmOS state:** boots → Phosh mobile UI (720×1280, GPU-accelerated,
touch) with Wi-Fi + **working audio** (this session's UCM). Remaining: on-device
reflash-validate of the published image; audio route polish (earpiece/headset
under phosh); modem (needs SIM); sensors (vibrator/prox/ALS); cameras
(disabled in DT).

## 2026-07-21 — Durable Phosh image + GitHub Release

Closed the durability gap from the Phosh bring-up: the UI had been `apk add`ed
onto a console rootfs and would not survive `pmbootstrap install`.

**What changed**
- `deviceinfo-motorola-perry` pkgrel 0→1: still pins `deviceinfo_dtb`, and now
  also ships `/var/lib/systemd/linger/xylitol` (same as `loginctl enable-linger`).
- New `scripts/pmos-build-phosh-release.sh`: applies all overlays, sets
  `ui=phosh`, builds with `--add deviceinfo-motorola-perry,firmware-motorola-perry-nv,alsa-ucm-motorola-perry`,
  exports, zstd-compresses the rootfs, loop-mount sanity-checks (extlinux
  `fdt /msm8917-motorola-perry.dtb`, DTB present, NV at DTS path, UCM, phosh,
  linger), stages `FLASH.md` + `SHA256SUMS`.
- Docs: `docs/pmos.md`, `pmos/README.md`, handoff updated.

**Build result**
- Image: `qcom-msm89x7.img` **4935M** (boot 512M + root with `extra_space=2048`)
- Compressed: **~557 MiB** `.img.zst` (fits GitHub Releases easily)
- lk2nd: perry node carry (r3), 315 KiB
- Password for the public image: `xylitol` (documented; change after first boot)

**Published:**
[https://github.com/aneesh-pradhan/xylitol/releases/tag/pmos-perry-2026-07-21](https://github.com/aneesh-pradhan/xylitol/releases/tag/pmos-perry-2026-07-21)

**Not yet done at publish time:** hardware reflash-validate.

**Reflash-validate PASS (same day):** flashed release `lk2nd-msm8952-perry.img`
→ `boot` and `qcom-msm89x7-perry-phosh.img` → `userdata` from lk2nd fastboot
(`lk2nd:device: perry`). After `fastboot continue`: USB-net + SSH, kernel
`7.0.9-msm89x7`, `graphical.target` + greetd active, phosh + phoc running,
extlinux has `fdt /msm8917-motorola-perry.dtb`, linger marker present,
UCM + WCNSS NV + all four perry apks installed, **wlan0 connected**. Sacred
partitions never touched. Host gotcha: NetworkManager on the build host can
steal the cdc_ncm iface — `nmcli device set <iface> managed no` before
assigning `172.16.42.2/24`.

## 2026-07-21 — Privacy scrub (public image + repo defaults)

Public defaults must not embed personal identity or host secrets:

- Image / docs default user: **`xylitol`** (was a personal username).
- Public image password default: **`xylitol`** (was a personal throwaway).
- Release builds set `pmbootstrap config ssh_keys False` — no host
  `authorized_keys` baked in.
- No Wi-Fi `*.nmconnection` profiles in the image (asserted by the release
  script). A live-device SSID profile that appeared after flash-validate was
  deleted on-device; it was never in the published artifact.
- APKBUILD Maintainer lines and `setup-env.sh` no longer ship personal emails;
  `setup-env.sh` requires `GIT_USER_*` or an existing git global identity.
- Chronology in this log still mentions GitHub repo URLs under the project
  owner path; that is the public repo location, not a device login.

## 2026-07-21 — Scrub AI co-author trailers + contributor list

Found `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` on two
reachable commits (`pmos: add perry ALSA UCM…`, `docs: perry boots to Phosh…`).
Rewrote all refs with `git filter-branch --msg-filter` to drop AI co-author
trailers, pruned `refs/original` + reflog, force-pushed `main` /
`twrp/ci-release` / tags.

Then ran the **main → main1 → main** default-branch rename dance so GitHub's
contributors list drops AI bot accounts (same trick used earlier for
`cursoragent`).

Hard enforcement added:

- `AGENTS.md` + `.cursor/rules/no-ai-commit-attribution.mdc` (alwaysApply)
- Versioned hooks: `scripts/git-hooks/{prepare-commit-msg,commit-msg}` —
  enable with `git config core.hooksPath scripts/git-hooks`
- CI: `.github/workflows/no-ai-coauthor.yml`

## 2026-07-21 — Phase B: linux-motorola-perry + device-motorola-perry (build)

Cut over from generic `qcom-msm89x7` overlays to first-class packages:

- `linux-motorola-perry` 7.0.9-r0 — msm89x7-mainline tarball + xylitol
  patches 0001–0006; defconfig seeded from msm89x7 (not yet P1-scrubbed).
- `device-motorola-perry` 1-r1 — single DTB pin, NV + UCM depends, linger,
  **P0** baked in:
  - `deviceinfo_zram_swap_pct=100` / `zstd` (postmarketos-zram already in base)
  - `/etc/environment.d/50-perry-wlr.conf` → `WLR_DRM_NO_ATOMIC=1`
  - lean install via `pmbootstrap install --no-recommends` (no firefox/cups/…)
  - udev USB UDC nosuspend + systemd preset masking cups/flatpak/fprintd/tuned
- Unblocked aport name clash by removing local copies of upstream
  `device/archived/{device,linux}-motorola-perry` (stale 3.18 fork).

Sanity on staged image (`artifacts/pmos-phase-b/motorola-perry-phosh.img`):
extlinux `fdt /msm8917-motorola-perry.dtb`, DTB present, linger, WLR env,
WCNSS NV, UCM, kernel.release `7.0.9-msm89x7`, no firefox-esr.

Scripts: `pmos-build-phase-b.sh`, `pmos-flash-phase-b.sh`. Flash-validate
blocked on reaching lk2nd fastboot (running image SSH password unknown).

## 2026-07-21 — Park Phase B flash; canonicalize custom kernel in-repo

Stopped hardware flashing mid-bring-up: force-fastboot lk2nd worked, but
`fastboot flash userdata` hung on sparse chunk 3/3 (twice); abort left lk2nd
USB wedged. User redirected to repo-side DT/kernel work.

In-repo cleanup:

- `pmos/linux-motorola-perry/` is the **canonical** home for perry DT/panel
  patches (`patches/0001–0006`) and tracked `config-motorola-perry.aarch64`
  (removed from `.gitignore`).
- `pmos/device-motorola-perry/` remains the first-class deviceaport (P0
  drop-ins + single DTB pin).
- `scripts/pmos-apply-perry-kernel.sh` now copies patches from
  `linux-motorola-perry/patches/` (legacy overlay folder stays a mirror).
- Published `qcom-msm89x7` + `pmos-build-phosh-release.sh` path unchanged.
- Flash helpers retained but parked (`pmos-flash-phase-b*.sh`).

Next without device: P1 defconfig scrub / numbered `01xx` DT-perf patches.

## 2026-07-21 — P1 (repo-side): defconfig scrub, eMMC udev, cpufreq audit

No flash (still parked). Changes in xylitol only:

**P1.1 + P1.6** — `pmos/linux-motorola-perry/config-motorola-perry.aarch64`,
`pkgrel` → 1:

- `HZ` 300 → 250 (`NO_HZ_IDLE` kept; no `NO_HZ_FULL`)
- Off: function tracer / dynamic ftrace (kept `CONFIG_FTRACE` + tracepoints),
  `DYNAMIC_DEBUG`, `FW_LOADER_DEBUG`, `CIFS_DEBUG*`, `BLK_DEBUG_FS`
- Off: non-perry Motorola/Xiaomi `DRM_PANEL_*` modules; kept perry Ofilm +
  Tianma
- Intentionally **did not** run host `olddefconfig` (earlier attempt rewrote
  Alpine clang / SCS / CFI markers to Ubuntu GCC — discarded)

**P1.2** — audited only: `msm8917.dtsi` CPU OPPs already 960 / 1094.4 / 1248 /
1401.6 MHz + cooling-cells; schedutil default; no DT patch until measured.
Noted in `pmos/linux-motorola-perry/patches/README.md`.

**P1.4** — `device-motorola-perry` pkgrel → 2: udev
`60-perry-emmc-scheduler.rules` sets `mq-deadline` on `mmcblk0`.

**Build validation:** `pmbootstrap build` succeeded for
`linux-motorola-perry` **7.0.9-r1** (~25 min) and `device-motorola-perry`
**1-r2**.

**Still open:** P1.3 GPU opp/cooling, P1.5 earlier DRM/splash, on-device
baselines after flash resumes.

## 2026-07-21 — P1.5 framebuffer-wait fix (repo-side, no flash)

[GitHub #4](https://github.com/aneesh-pradhan/xylitol/issues/4). Root cause
(confirmed by reading `postmarketos-initramfs` 3.12.0 source, extracted from
`~/pmos/work/cache_distfiles/postmarketos-mkinitfs-2.11.1.tar.gz` and the
live pmaports checkout): `init_functions.sh`'s `setup_framebuffer()` waits a
hardcoded `seq 1 100` × `sleep 0.1` = **10s** for `/dev/fb0`, then gives up
and logs `ERROR: /dev/fb0 did not appear after waiting 10 seconds!` without
ever calling `set_framebuffer_mode()`. Perry's Ofilm 499v0 DPU/DSI DRM driver
doesn't bind until **~27s** in (already known, see 2026-07-20 "Retire
Solution-2 DTB hacks" — that entry named the initramfs-timeout bump as the
correct low-risk path, not simplefb). This is why perry gets a silent black
screen through the whole boot instead of any splash/console.

**Fix:** `pmos/postmarketos-initramfs/0001-make-framebuffer-wait-timeout-device-configurable.patch`
adds `deviceinfo_framebuffer_wait_seconds` (default `10`, so every other pmOS
device is unaffected); `setup_framebuffer()`'s loop count and error message
now derive from it. Perry's own
`pmos/device-motorola-perry/deviceinfo` sets it to `35` (27s observed +
margin). New `scripts/pmos-apply-initramfs-perry.sh` (mirrors
`pmos-apply-lk2nd-perry.sh`'s pattern: copy patch into the local pmaports
`main/postmarketos-initramfs`, bump `pkgrel`, insert into `source=`,
re-checksum) wired into `scripts/pmos-build-phase-b.sh`.

**Four gotchas hit getting this to actually build + land in the rootfs**
(each confirmed by direct inspection, not assumption — worth remembering for
future community-package patches or first-class package edits):

1. **awk closing-quote match bug.** The apply script's insert-into-`source=`
   awk looked for a line starting with `"` to find the block's end. lk2nd's
   `source=` block closes with an unindented `"`, but
   `postmarketos-initramfs`'s closes with a **tab-indented** `"` (multi-entry
   block) — the awk skipped past it and matched the `sha512sums=` block's
   closing `"` instead, silently mis-inserting the patch line into the wrong
   block. `pmbootstrap checksum` then regenerated `sha512sums=` from the
   *actual* `source=` list (which never got the patch), silently discarding
   the bad insert — so the APKBUILD looked "fixed" (pkgrel bumped, patch file
   copied) but the patch was never actually wired in. Fix: match
   `/^[ \t]*"[ \t]*$/` instead of `/^"/`.
2. **abuild `default_prepare()` needs `$builddir` for `.patch` sources.**
   `postmarketos-initramfs` ships plain files (no tarball), so its APKBUILD
   never sets `builddir=`. abuild's `default_prepare()` requires
   `[ -d "$builddir" ]` before applying any `.patch` entry —
   `ERROR: Is $builddir set correctly?`. Fix: add `builddir="$startdir"`.
   First attempt used `builddir="$srcdir"` instead — abuild's default
   `$srcdir` is populated with **symlinks** back into `$startdir` for local
   sources, and `patch` refuses to edit through a symlink
   (`File init_functions.sh is not a regular file -- refusing to patch`).
   `$startdir` has the real files; `$srcdir/init_functions.sh` symlinks to
   the same path, so `build()`/`package()` (which reference `$srcdir`) pick
   up the patched content automatically.
3. **`arch="noarch"` defaults to the native host arch, not the target.**
   `pmbootstrap build postmarketos-initramfs` (no `--arch`) only produced an
   `x86_64` apk with no `aarch64` index entry. The perry rootfs (aarch64)
   installed fine anyway — apk silently fell back to the **unpatched
   upstream r0** binary from the remote mirror instead of erroring, so the
   sanity check (`grep` for the new function in the built rootfs) was what
   actually caught it, not a build failure. Fix:
   `pmbootstrap build postmarketos-initramfs --arch aarch64`.
4. **`device-motorola-perry`'s `deviceinfo` install path is NOT
   `/etc/deviceinfo`.** `devicepkg_package.sh` (from `devicepkg-dev`) installs
   to `usr/share/deviceinfo/$pkgname`, symlinked from
   `usr/share/deviceinfo/deviceinfo`. `/etc/deviceinfo` doesn't exist on this
   image at all. Also unrelated but compounding: **`device-motorola-perry`'s
   `pkgrel` wasn't bumped** after editing `deviceinfo`, so `pmbootstrap
   build` kept reusing an hours-old cached apk from earlier in the session
   with none of the P1.5 change — content checksums matched in the *source*
   APKBUILD (`pmbootstrap checksum` re-hashes correctly), but apk versioning
   is pkgrel-based, not content-hash-based, so nothing forced a rebuild.
   Fixed both: sanity check now greps
   `usr/share/deviceinfo/deviceinfo`, and `device-motorola-perry` bumped
   `pkgrel` 2 → 3.

**Environment note (unrelated to the patch, but ate most of the session):**
`pmbootstrap`'s buildroot teardown (`zap_buildroots`) intermittently lost a
race unmounting `chroot_native/{proc,sys,mnt/...}` with `target is busy` on
this desktop (busy with GNOME's `localsearch` indexer, editors, browser tabs,
etc. all touching `/proc`). Recovery: `sudo umount -l <mountpoint>` (lazy)
followed by `pmbootstrap shutdown`, then retry — never needed more than a few
attempts. Not a xylitol or patch issue; purely host noise.

**Build validation:** full `scripts/pmos-build-phase-b.sh` run succeeded
end-to-end (packages up to date except the two above, which rebuilt
correctly) with all sanity checks passing, including two new ones added for
this fix (patched `init_functions.sh` present, perry's
`deviceinfo_framebuffer_wait_seconds="35"` present). Extracted and directly
verified the built apks/rootfs contents at each step rather than trusting
"up to date" / exit-code-0 alone — this is what caught gotchas 3 and 4 above.
**Not yet confirmed on hardware** — flash is still parked; next flash should
visually confirm a splash appears instead of a black screen for ~27s.

## 2026-07-21 (later) — flash checkpoint: fresh P1/P1.5 image flashed to hardware

User asked for a "sanity check checkpoint": push today's build (P1 kernel
scrub + P1.5 framebuffer-wait fix) to the device for them to verify, after
the [P1.5 PR (#14)](https://github.com/aneesh-pradhan/xylitol/pull/14) was
merged. Device was already sitting in stock fastboot (`product: perry`,
serial `ZY224TB8KZ`) when the session started — no physical interaction
needed to begin.

**Gotcha found before flashing:** `scripts/pmos-flash-phase-b-force.sh`
(the proven-working path, per handoff.md history of two prior hangs on the
plain `fastboot flash userdata` path) reads
`artifacts/pmos-phase-b/motorola-perry-phosh.sparse.img`, but
`scripts/pmos-build-phase-b.sh` only ever produces the **raw**
`motorola-perry-phosh.img` — it never regenerates the sparse variant. The
`.sparse.img` sitting in `artifacts/` was stale from an early session
(00:36 timestamp, hours before *any* of today's P1/P1.5 work). Flashing it
as-is would have silently pushed old content and defeated the entire point
of the checkpoint. Fixed by regenerating fresh before every flash:
```bash
img2simg motorola-perry-phosh.img motorola-perry-phosh.sparse.img
```
(`lk2nd-force-fastboot.img` did **not** need regenerating — lk2nd itself
was untouched this session, confirmed via the build logs showing
"Package 'lk2nd' is up to date" throughout.)

**Flash sequence (all via `pmos-flash-phase-b-force.sh`), full log kept at
session scratchpad `flash-phase-b.log`:**
1. Stock fastboot → `fastboot flash boot lk2nd-msm8952-perry.img` (normal
   lk2nd written to `boot`) → `fastboot boot lk2nd-force-fastboot.img`
   (RAM-only boot of the force-fastboot variant, no flash).
2. Waited for `product=lk2nd-msm8952` (succeeded on the first check, `t=1`).
3. `fastboot flash -S 100M userdata motorola-perry-phosh.sparse.img` — 12
   chunks of ~100MB each. Chunks 1–11 each completed in 2.5–4.6s. **Chunk
   12/12 (the last one) took 187.1 seconds to write** — no host-side CPU
   activity during that window (`ps` showed the `fastboot` process in `D`
   state, i.e. genuinely blocked on device I/O, not spinning or crashed).
   This *looked* exactly like the historical "hung on chunk 3/3" failure
   mode from handoff.md while it was happening — the distinguishing signal
   that it wasn't actually stuck was the process state (`D`, alive, blocked
   on I/O) rather than a dead/zombie process, plus the fact it eventually
   completed on its own without any intervention. **Do not assume a
   long-sitting final chunk is a hang — check `ps aux | grep fastboot` for
   process state before considering any recovery action.** Total flash
   time: 306.5s (~5 min), matching the script's own "5–10 minutes" estimate.
4. `fastboot flash boot lk2nd-msm8952-perry.img` again (restore normal
   lk2nd so the device boots pmOS normally afterward, not straight back
   into force-fastboot).
5. `fastboot continue` → `FLASH_COMPLETE`.

**Sacred partitions:** never touched — only `boot` (lk2nd, twice, both
non-destructive/reversible) and `userdata` (destructive there, expected and
documented). No `persist`/`modemst1`/`modemst2` interaction at any point.

**Outcome:** flash completed cleanly, device resumed boot via
`fastboot continue`. **On-device visual/SSH confirmation is the user's to
do** (they explicitly asked to verify themselves) — specifically whether
Phosh boots normally and whether the P1.5 splash now renders instead of the
~27s black screen. See handoff.md "Next session — start here (post-flash
checkpoint)" for the follow-up.

## 2026-07-21 (afternoon) — incident recovery: clean rebuilds, rollback boots, bisect A launched

Recovery session for the boot-hang + fastboot-wedge incident (see handoff.md
"Boot-hang incident" + its RESOLUTION UPDATE). Host-first strategy per user:
purge caches, rebuild everything clean, only then touch the device.

**Root causes established (host side):**

1. **lk2nd package-cache poisoning** — the Phase B FORCE_FASTBOOT lk2nd
   build overwrote `lk2nd-msm8952-22.0-r3.apk` in `~/pmos/work/packages`
   without a pkgrel bump. Every subsequent install saw "up to date" and
   embedded the FORCE binary as the *normal* boot lk2nd (`b884ee70…` — the
   mystery second SHA from the flash checkpoint entry is exactly this).
   Fixed: purged poisoned apks, `pmbootstrap build lk2nd --force` from a
   pristine APKBUILD → clean NORMAL matches the release SHA `8d7851b4…`.
   Both build and flash scripts now hard-fail if the NORMAL image contains
   the force-fastboot marker string, and the flash script refuses a sparse
   image older than its raw.
2. **Raw-image SHA dirtying** — RW loop-mount inspection had modified
   journal/superblock bytes of flashable raws. Dirtied copies quarantined
   (`artifacts/quarantine-2026-07-21/`); rebuilt release raw from the
   SHA-verified `.zst`. All inspection mounts are now `ro,noload`.
3. Full clean Phase B rebuild: initramfs (aarch64), kernel `7.0.9`
   (`--force`), device pkg, `install --zap`, export, fresh `img2simg`
   sparse, SHA256SUMS. `--lax` used on builds to dodge the recurring busy-
   chroot `umount` failure on this host.

**Device recovery (single controller, flock-guarded):**

- User physically reset the phone into stock fastboot → Symptom 2 (protocol
  hang) *gone*: `getvar product` in 6 ms, 10/10 stability probes over 2.5
  min, full `getvar all` OK. Verdict: transient bootloader/USB wedge cleared
  by power-cycle; host and cable exonerated.
- Rollback flash (release NORMAL lk2nd → `boot`; FORCE RAM-boot only;
  release sparse → `userdata`, 20 chunks, 360 s total, last chunk 62 s —
  again `D`-state I/O, not a hang) → `fastboot continue` →
  **device boots to Phosh, user-confirmed login** (creds `xylitol`/`xylitol`
  — NOT the pmOS default 147147; worth remembering, user hit this).
- USB-net gotcha: the gadget MAC is randomized per boot, so the host iface
  is a new `enx…` name each time — a previous session's static-IP
  assignment lands on the wrong iface. Assign `172.16.42.2/24` to the
  *current* `enx…` (check `dmesg | grep cdc_ncm`).

**Decision-tree outcome: Symptom 1 = Phase B image content**, not
flash/eMMC/hardware. Differential evidence from the running known-good
system (`artifacts/pmos-phase-b/evidence-rollback-boot/`):

- Known-good initramfs never early-loads the perry Ofilm panel driver —
  its `initramfs.load` is the generic msm89x7 set (ofilm binds later from
  rootfs udev). Phase B's `modules-initfs` *added*
  `panel_motorola_perry_499v0_ofilm` to early boot → prime suspect: early
  `modprobe -a` hang before USB gadget setup (matches "zero USB, black
  screen" exactly).
- Known-good kernel: `CONFIG_HZ=300`; Phase B P1 scrub: `CONFIG_HZ=250`
  (verified in both artifacts) — bisect variant B if A doesn't clear it.

**Bisect A prepared:** `device-motorola-perry` r4 drops ofilm from
`modules-initfs`; clean `motorola-perry-phosh-bisectA.img` built via
`install --zap` (first attempt failed on `mkfs.ext4 /dev/installp2` due to
stale chroot mounts from the prior install — cleared with `pmbootstrap
shutdown` + lazy umounts + retry). Pass criterion: USB-net/SSH within ~30 s
of `continue`. Kernel stays the P1 scrub (HZ=250) so A isolates the
modules-initfs variable only.

## 2026-07-21 (evening) — Bisect A FAIL; Bisect B (HZ=300) building

**Bisect A flash** (ofilm out of `modules-initfs`, kernel still HZ=250):
- Flash via `pmos-flash-phase-b-force.sh` with bisectA sparse — clean
  `FLASH_COMPLETE` (~307s userdata; chunk 12/12 write 188s, normal eMMC).
- NORMAL lk2nd `8d7851b4…`, FORCE RAM-boot only. Sacred partitions untouched.
- **User-confirmed hang:** same Symptom 1 — backlight on, black screen,
  frozen, no USB. Early ofilm modprobe is **not** the sole hang cause.

**Flash-script bug fixed mid-session:** `strings | grep -q` under `set -o
pipefail` false-negatived the FORCE marker (SIGPIPE). Switched to
`grep -aFq` on the binary in both flash and build scripts.

**Bisect B:** activated `CONFIG_HZ=300` (rest of P1 scrub kept),
`linux-motorola-perry` pkgrel=2, modules-initfs still = A. Full
`pmos-build-phase-b.sh` running → `motorola-perry-phosh-bisectB.*`.

## 2026-07-21 (evening) — Bisect B FAIL; Bisect C (full upstream defconfig) building

**Bisect B:** `linux-motorola-perry` pkgrel=2, `CONFIG_HZ=300`, modules-initfs
still without ofilm early load. Built clean (HZ=300 verified in boot
partition). Flashed ~21:53Z, `FLASH_COMPLETE` (~306s). USB/SSH probe 150s
→ **FAIL** (same black-screen hang class). **HZ is not the root cause.**

**Bisect C:** replace perry scrubbed defconfig with full upstream
`config-postmarketos-qcom-msm89x7.aarch64` (pkgrel=3). Isolates entire P1.1
scrub. Build + auto-flash via CDE orchestrator; on fail → known-good
rollback.

## 2026-07-21 (evening) — Bisect C image READY; flash blocked on device access

Bisect C image built and verified (`FUNCTION_TRACER=y`, `DYNAMIC_DEBUG=y`,
`HZ=300`, pkgrel=3):
`artifacts/pmos-phase-b/motorola-perry-phosh-bisectC.{,sparse.}img`.

Host waited 20 min for stock fastboot after Bisect B hang — **no USB
enumeration at all** (no 22b8/18d1 in lsusb). Phone either unplugged,
still hung with USB dead, or needs a different cable/port.

Waiter restarted for 60 min (`waiter2.pid`): on `product: perry` will
flash C → SSH probe → known-good rollback if C fails.

**User action:** force power-off + stock fastboot (Vol-Down+Power), confirm
USB cable to host.

## 2026-07-21 (night) — Bisect C FAIL; known-good rollback pending

**Bisect C flash** (full upstream msm89x7 defconfig, `linux-motorola-perry`
pkgrel=3, ofilm still out of early modules-initfs): clean `FLASH_COMPLETE`
(~306s, 13 sparse chunks). User-confirmed: **same hang** — backlight on,
black screen, frozen, no USB.

**A/B/C all FAIL** → hang is not ofilm-early-load, not HZ=250, not the
P1.1 defconfig scrub. Regression surface is the first-class
`device-motorola-perry` + `linux-motorola-perry` Phase B path (or shared
P1.5 initramfs / install recipe). Known-good remains
`qcom-msm89x7` overlay release `pmos-perry-2026-07-21`.

**Rollback:** waiter armed for stock fastboot → flash
`qcom-msm89x7-perry-phosh.sparse.clean.img` + release lk2nd.

## 2026-07-22 (early) — known-good rollback FLASH_COMPLETE

After Bisect C hang, interrupted partial rollback (chunk 6/20) was discarded.
Clean rollback from **stock** fastboot (`product: perry`, ZY224TB8KZ):

- Image: `pmos-perry-2026-07-21` sparse.clean + release NORMAL lk2nd
- Flash: 20/20 chunks OK (~356s), `FLASH_COMPLETE`, normal lk2nd restored,
  `continue`
- Post-flash: USB gadget enumerated (`18d1:d001` / cdc_ncm `enx…`); brief
  ping success then flaky (autosuspend / late boot). SSH not confirmed from
  host in the probe window — **user should confirm Phosh on glass**.

**Bisect summary:** A (ofilm early) / B (HZ) / C (full defconfig) all hang.
Phase B first-class path regresses boot; known-good `qcom-msm89x7` path is
the recovery baseline.

## 2026-07-22 — docs PR: Phase B hang bisect closed out on known-good

Device **SSH-confirmed** on known-good overlay release
`pmos-perry-2026-07-21` (`7.0.9-msm89x7`, `deviceinfo-motorola-perry`,
Ofilm from rootfs, Wi‑Fi + USB-net).

Canonical bisect report + next isolation tasks **T1–T6**:
`docs/phase-b-boot-hang-bisect.md`. Handoff top rewritten for next session.

In-repo after docs PR: `device-motorola-perry` pkgrel 4 (no early ofilm);
`linux-motorola-perry` pkgrel 1 (scrubbed defconfig + HZ=250 restored as
product intent — **not boot-validated**). Flash tooling: env overrides +
`grep -aFq` FORCE check; `scripts/pmos-rollback-known-good.sh`.

## 2026-07-22 — Bisect D PASS (P1.5 hang root cause); T6 baselines

**Hang root cause:** P1.5 framebuffer-wait initramfs patch +
`deviceinfo_framebuffer_wait_seconds=35`. A/B/C still failed with that
combo present; **Bisect D** (drop P1.5 only; scrubbed HZ=250 kernel r1;
device r4 no early ofilm; unpatched initramfs r0) **boots**.

- Flash: `FLASH_COMPLETE` ~305s userdata (chunk 12 ~187s eMMC).
- USB-net ~5s; SSH ~25s after continue.
- Live: `linux-motorola-perry` 7.0.9-r1 `#2-perry-xylitol`, Phosh,
  Ofilm 720×1280, Wi‑Fi + Developer Mode USB-net.
- Product: default Phase B build **P1.5 off** (`ENABLE_P15=1` research-only);
  deviceinfo documents disabled wait; device pkgrel **5**.

**T6 idle baselines** (Phosh up; raw under
`artifacts/pmos-phase-b/evidence-bisectD-boot/`):

| Metric | Value |
|---|---|
| Boot | kernel 19.9s + userspace 26.6s = **46.5s**; graphical @ 23.9s userspace |
| RAM | ~447 MiB used / 1.8 GiB; zram 1.8 GiB zstd idle |
| CPU | schedutil; OPPs 960–1401.6 MHz; HZ=250 |
| eMMC | mq-deadline |
| GPU | simple_ondemand; 19.2–598 MHz OPPs |
| Audio | Speaker + Mic1 sinks; `speaker-test` 880 Hz sine OK |

P1.3: baselines only — no GPU DT until a measured need. See plan §5 and
`phase-b-boot-hang-bisect.md`.

## 2026-07-22 — Upstream #13: panel-drivers#8 (Ofilm) + linux#48 adoption note

Pushed xylitol `24d149e` (Bisect D / P1.5 off). Then started [issue #13](https://github.com/aneesh-pradhan/xylitol/issues/13):

- Opened [linux-panel-drivers#8](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/8): perry config for Tianma 499v1 + Ofilm 499v0; DTB from #6 lineage (already contains ofilm MDSS node); generator verified.
- Commented on panel #6 and kernel #48 (adoption + multi-panel evidence).
- Next upstream: rpmcc split (step A), then msm8920.dtsi / perry DTS re-roll.

## 2026-07-22 — Upstream #13 step A: rpmcc-msm8920 patch staged

Drafted mainline-targeted patch (against torvalds/linux master as of today):

- `upstream/rpmcc-msm8920/0001-clk-qcom-smd-rpm-add-support-for-MSM8920.patch`
- MSM8920 rpmcc table = msm8917 clocks + IPA (from msm8940); yaml compatible
  `qcom,rpmcc-msm8920` in enum + pxo/cxo group
- `git apply --check` OK; README has send-email targets (andersson@ + linux-arm-msm)
- Not mailed yet — optional dt_binding_check on full tree before send

Panel track unchanged: linux-panel-drivers#8 still open.

## 2026-07-22 EOD — handoff freeze (productize next)

Session pause. Handoff top rewritten for next session:

- Device stays on **Bisect D** first-class image (`device` 1-r4 on phone).
- **Do next:** rebuild/flash clean Phase B from `main` (P1.5 off, device
  pkgrel 5) — productize, not another hang bisect.
- Upstream mail (rpmcc step A) **held** per maintainer; patch stays in
  `upstream/rpmcc-msm8920/`.
- Git tip `03e911e` on origin/main.

## 2026-07-22 late — lk2nd 23.1 on device; drop local perry carry

**Goal:** ride pmaports [!9076](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/merge_requests/9076)
(main/lk2nd → 23.1) instead of xylitol's 22.0-r3 + `pmos/lk2nd/0001-*` backport
of upstream `d9ce4e70`.

**Build:** local pmaports `main/lk2nd` set to MR 23.1-r0 (onclite patch only; no
perry patch). `pmbootstrap build lk2nd` → `lk2nd-msm8952-23.1-r0.apk`. FORCE twin
built on host with `LK2ND_FORCE_FASTBOOT=1` (not installed into apk cache).

**Flash:** permanent update required **stock Motorola fastboot** (`product:
perry`). Flashing `boot` from inside older lk2nd reported OKAY but left
`lk2nd:version` at `22.0-r3-postmarketos` until stock flash.

**On-device (after stock flash):**
- `lk2nd:version` = **`23.1-r0-postmarketos`**
- `lk2nd:device` / `model` = perry / Motorola Moto E4 (perry) (MSM8917)
- `oem log`: Detected device … (compatible: motorola,perry) — no FIXME/`-1`
- `fastboot continue` → OS `7.1.3-msm89x7`, Phosh/greetd active, USB-net+SSH

**Repo cleanup:** deleted `pmos/lk2nd/0001-*` and
`scripts/pmos-apply-lk2nd-perry.sh`; unhooked from
`pmos-build-phase-b.sh` / `pmos-build-phosh-release.sh`. Docs:
[`pmos-lk2nd-perry-node.md`](pmos-lk2nd-perry-node.md), handoff top-of-file.

**RFT:** posted on !9076 as note 571627 (`aneesh-pradhan`); source text also at
`artifacts/pmos-phase-b/lk2nd-23.1-rft-comment.md`
(Tested-by: Aneesh Pradhan \<aneeshpradhan@acm.org\>).

**Session close:** handoff top rewritten with full session log + scoped
next-session board (default: full-apps UX smoke). Git `82f21c0` / `0f3d3ee`
on origin/main.

## 2026-07-22 — UX: severe GPU hang under Neverball (Adreno ringbuffer / recover −22)

User smoke on Phosh **7.1.3-msm89x7**: graphics stress with **Neverball**
trips msm/adreno:

```
drm:adreno_idle [msm]] *ERROR* 03000620: timeout waiting to drain rungbuffer 0 rptr/wptr = 10/12
msm_dpu 1a01000.display-controller: [drm:adreno_recover [msm]] *ERROR* gpu hw init failed: -22
```

Logged as handoff track **1b** (SEVERE). Prior matrix only confirmed GPU
bound + basic GL — not game load. P1.3 opp work still baselines-only;
hang may justify revisiting after full dmesg/mesa capture. Not bisected
vs 7.0.9 / mesa yet.

## 2026-07-22 — UX: camera app finds zero devices on pmOS (Android work N/A)

User: Phosh camera app opens; **no cameras found**. Logged as handoff
track **1c**.

**Applicability of LineageOS 18.1 camera work:** the Android path
(patches 0011–0015, montana platform blobs, qcamerasvr, 3.18 CCI) does
**not** run on pmOS mainline. Useful carry is hardware intel only
(sensor IDs / GPIOs / regulators) for a future CAMSS + libcamera bring-up;
not a port of the vendor HAL.

**Priority pivot (same day, user):** camera is **#1 sole active track** —
GPU hang, UX polish, upstream follow-through, and other board items are
**blocked** until at least one sensor enumerates and can preview/capture
under pmOS. Handoff board rewritten accordingly.

## 2026-07-22 EOD — session close (upstream mailed + camera #1 + DTS v2)

**Context window close-out.** Full state in `docs/handoff.md` top
("CAMERA FIRST"). Summary:

1. **barni2000 Gates 3+4 mailed** to linux-arm-msm (rpmcc + initial
   MSM8920/perry DTS). Fork notes on linux#48 / #57.
2. **DTS v2** re-roll: Makefile DTB alphabetical sort (Sashiko). Lore
   `20260723014627.63310-1-aneeshpradhan@acm.org`.
3. **UX:** GPU hang under Neverball logged (parked). Camera zero-devices
   = **sole #1 priority**; all other tracks blocked.
4. **SMTP:** Gmail `aneeshpradhan2004@gmail.com` + From ACM; secrets
   outside repo.
5. Next opener: camera CAMSS bring-up only.

## 2026-07-22 — pmOS mainline camera: front OV5695 ENUMERATES (root cause: i2c addr 0x10, not 0x36)

**Milestone: the front camera comes up on mainline CAMSS.** From "Phosh sees
zero cameras / `/dev/video0..1` = Venus only" to a registered V4L2 subdev that
libcamera lists. Full reference: [`pmos-camera-perry.md`](pmos-camera-perry.md).
Capture (frame delivery) is **not** working yet — blocked on `VFE sof timeout`.

### What was disabled and what we enabled

Base `msm8917.dtsi` (fork `msm89x7/7.1.3`, the tag the pmOS kernel builds from)
already defines `camss@1b34000` (`qcom,msm8917-camss`) and `cci@1b0c000`
(`qcom,msm8974-cci`) plus all camera pinctrl — all `status = "disabled"`. So
nothing camera exists until DT flips them on. No other msm8917/msm8937 board
enables CAMSS on mainline, so perry is the first to exercise this path
(closest template: msm8916 `apq8016-sbc-d3-camera-mezzanine` / ov5640).

New carry patch **`pmos/linux-motorola-perry/patches/0007-...`**: enable
`&camss` + `&cci` (cci0 only), add front **OV5695** on CCI master 0 / CSIPHY1,
two gpio-switched fixed regulators (avdd gpio39 / dovdd gpio27, dvdd =
pm8937_l23). Config: `CONFIG_VIDEO_OV5695=m` (camss + cci i2c were already `=m`).

### Hardware map (from downstream `msm8917-camera-sensor-mot-perry.dtsi`)

- **Front OV5695** (mainline driver ✓): mclk2 gpio28 @24 MHz, reset gpio40
  (active low), CSIPHY1/CSID1, 2 lanes, CCI master 0.
- **Rear S5K4H8** (no mainline driver — deferred): mclk0 gpio26, standby
  gpio35, dw9718s AF (also no mainline driver).
- **CCI master-0 only**: cci1 = gpio31/32, and **gpio31 is owned by the sx9310
  SAR sensor** — downstream says keep cci0 only. Patch restricts `&cci`
  pinctrl to `cci0_default` and disables `cci_i2c1`.
- Rails gpio27 (VIO 1.8V) + gpio39 (VANA 2.8V) are shared load switches.

### Root cause of the initial probe failure: i2c address

First probe: `ov5695 2-0036: Unexpected sensor id(000000), ret(-5)`. Ruled out
methodically over SSH via `/sys/kernel/debug`:
- **Clock OK** — sampled `gcc_camss_mclk2_clk` across unbind/rebind:
  enable→1 @24 MHz, source PLL **gpll6** enable→1 (24 MHz needs gpll6:
  `F(24000000, P_GPLL6, 1, 1, 45)`; no XO 24 MHz path). A first `gpll6=0`
  sample was a read race.
- **Power OK** — made avdd/dovdd `regulator-always-on`; confirmed `enabled`;
  sensor still id 0. Not power/timing.
- **Address = the bug** — temporary driver debug patch `0008` retried the
  chip-id read and scanned 0x36 + 0x10:
  ```
  camdbg: addr=0x36 try=0..4 ret=-5 id=000000
  camdbg: addr=0x10 try=0 ret=0 id=005695 → Detected OV005695 sensor at 0x10
  ```
  **Perry straps OV5695 to slave address 0x10, not the OmniVision default
  0x36.** Detected on the first try at 0x10 → the extended settle delay was
  unnecessary. Reverted `0008` and the always-on rails; clean `0007` uses
  `reg = <0x10>` + driver-controlled rails.

### Proof (clean build, stock driver)

`ov5695 2-0010: Detected OV005695 sensor`; `/dev/media0` + video0..7 +
v4l-subdev0..14; media graph `ov5695 2-0010 → msm_csiphy1 [ENABLED]`;
`cam -l` → `1: 'ov5695' (…/camera@10)` at 2592×1944 (5 MP). **Satisfies the
"≥1 sensor enumerates" done-criterion.**

### Capture blocker (resolved same day — see next entry)

Initially `cam --capture` hit `VFE sof timeout`. Fixed 2026-07-22 night:
CSIPHY `data-lanes = <0 1>` + `vdda-supply = <&pm8937_l2>`. Details below.

### Workflow notes (reusable)

- **In-place deploy, no fastboot:** perry boots lk2nd → extlinux on `/boot`.
  `apk add --allow-untrusted <kernel.apk>` runs boot-deploy → rewrites
  `/boot` vmlinuz+dtb → reboot. `/boot` backed up to
  `/root/boot-bak-7.1.3-r1`. (`apk add <file>` reinstalls same version;
  there is no `--force-reinstall` — that's a dnf-ism.)
- **Build:** `pmbootstrap shutdown` before `build --force --lax` (stale chroot
  → pre-build zap hits the umount-busy race; `--lax` skips it). Warm ccache:
  DT/driver-only rebuild ~60 s.
- **Reconnect after reboot:** USB gadget MAC randomizes → new `enx*`; re-add
  `172.16.42.2/24` to it; **never** to `enp42s0` (dup /24 hijacks the route —
  silent 100% loss); `ip neigh flush all` after MAC change or SSH hangs.
- **SSH password** = owner's phone number → `SECRETS.md` (gitignored, new
  this session).

## 2026-07-22 night — front OV5695 FIRST LIGHT (capture works)

**Milestone: frames.** Front camera now streams on mainline CAMSS + libcamera.
Done-criterion "preview or still works" is **met** for the front OV5695.

### Experiments

1. CSIPHY `data-lanes` `<0 2>` → `<1 2>` (match sensor): still `VFE sof timeout`.
2. CSIPHY `data-lanes` **`<0 1>`** + **`vdda-supply = <&pm8937_l2>`** on
   `&camss`: **frames arrive**.

Live DT confirmed: CSIPHY lanes `00 00 00 00 00 00 00 01`, sensor
`00 00 00 01 00 00 00 02`, `vdda-supply` phandle present. dmesg no longer
logs `supply vdda not found`.

### Proof

```
cam --camera 1 --capture=5
# Input 2592x1944-BGGR-10-CSI2P stride 3240
# Capture 5 frames @ ~17.5 fps, bytesused 20404224 each
# no VFE sof / reg update timeout

cam --camera 1 --capture=2 --file=/tmp/camtest/frame.ppm
# 2584×1944 P6, nonzero_ratio≈0.62, regional RGB variation (real scene)
```

Artifact: `artifacts/camera-first-light-2026-07-22/ov5695-front-first-light.{ppm,jpg}`.

### Why it worked

- **Lanes:** qcom-camss uses CSIPHY `data-lanes` as 0-based physical positions
  for `lane_mask`. Sensor side stays V4L2 logical `<1 2>`. apq8016 mezzanine
  `<0 2>` is board-specific routing, not a generic 8x16 rule.
- **vdda:** msm8917 camss (`csiphy_res_8x39`) requests `"vdda"`; msm8916
  reference wires PMIC L2 1.2 V. Dummy regulator → no MIPI SOF on perry.

Full write-up: [`pmos-camera-perry.md`](pmos-camera-perry.md). Patch `0007`
committed as `83142f8` (`pmos/camera: OV5695 first light — CSIPHY lanes + CAMSS vdda`).

## 2026-07-22 night — PMI8950 flash/torch enabled (sysfs)

After OV5695 first light, enabled camera flash LEDs via mainline
`leds-qcom-flash-v1` (already in msm89x7/7.1.3 + `CONFIG_LEDS_QCOM_FLASH_V1=m`).

Patch `0008`: `&pmi8950_flash` status okay + `led@0`/`led@1` (same shape as
montana/hannah/cedric; torch ≤200 mA, flash ≤1000 mA).

On-device:
- `white:flash` + `white:flash_1` under `/sys/class/leds/`
- flash class attrs: brightness (torch), flash_strobe, flash_brightness, …
- dmesg: probe OK; dummy `flash-boost`/`torch-boost` (siblings also omit;
  boost is internal on this PMIC path)
- Kernel package **7.1.3-r2** on glass

Sysfs torch (both channels):
```
echo 16 | sudo tee /sys/class/leds/white:flash/brightness
echo 16 | sudo tee /sys/class/leds/white:flash_1/brightness
# … then echo 0 to both to turn off
```

**Channel map (user-confirmed torch test, L0 then L1 ×2):**
- `led@0` / `white:flash` → **rear**
- `led@1` / `white:flash_1` → **front**

## 2026-07-22 EOD freeze — camera session summary (for next opener)

**Massive progress recorded in** [`pmos-camera-perry.md`](pmos-camera-perry.md)
**and** [`handoff.md`](handoff.md) (local).

| Done | Detail |
|---|---|
| Front OV5695 first light | enumerate @0x10 + capture ~17.5 fps; `0007`; commit `83142f8` |
| PMI8950 flash/torch | `0008`; on glass **7.1.3-r2**; rear=`white:flash`, front=`white:flash_1` |
| Artifact | `artifacts/camera-first-light-2026-07-22/` (gitignored) |

| Next | Detail |
|---|---|
| 1 | Commit `0008` + APKBUILD pkgrel=2 + docs if still dirty |
| 2 | Rear recon: i2c scan S5K4H8 + dw9718s (mclk0, gpio35 standby, CSIPHY0) |
| 3 | New mainline drivers for s5k4h8 then dw9718s |
| 4 | Optional: Phosh Snapshot, GPU hang 1b, upstream replies |

Do not re-send upstream DTS v1; v2 is current. Authorship acm.org only.

## 2026-07-22 night — rear S5K4H8 ENUMERATE (probe + chip-id)

Front first light + flash already on glass (**7.1.3-r2**). This session:
stock reverse-eng → minimal mainline driver → DT → deploy **7.1.3-r3**.

### Stock reverse-eng (host)

| Artifact | Finding |
|---|---|
| `libmmcamera_s5k4h8.so` | slave **0x5A** (8-bit write → 7-bit **0x2d**), chip id **0x4088**, MCLK 24 MHz, **3264×2448** |
| `libactuator_dw9718s.so` | `dongwoon` / `dw9718s`, slave **0x18** → 7-bit **0x0c** |
| Downstream `msm8917-camera-sensor-mot-perry.dtsi` | mclk0/gpio26, standby gpio35, CSIPHY0, LaneMask `0x1F`, VAF l22 |

### Patches / package

| Item | Detail |
|---|---|
| `0009` | `media: i2c: add Samsung S5K4H8 sensor (probe/chip-id)` — power, CCI scan, id read; no stream tables yet |
| `0010` | DT `camera@2d` + camss `port@0` (4-lane CSIPHY0) |
| Config | `CONFIG_VIDEO_S5K4H8=m` |
| pkgrel | **3** (on glass `#4-perry-xylitol`) |
| Apply script | copy all `NNNN-*.patch` (was `000*` only — missed 0010) |

### On-device proof

```
s5k4h8 2-002d: recon: reset deasserted (active-low try)
s5k4h8 2-002d: cci scan: addr=0x2d reg0000=0x4088
s5k4h8 2-002d: Detected S5K4H8 sensor (id 0x4088)
# other scan addrs ret=-6 (incl. 0x0c AF — VAF not powered)
# front OV5695 still captures ~17.6 fps (shared-rail regression OK)
```

libcamera: rear entity present but skipped (missing mandatory V4L2 controls
+ no `s_stream`). Front still listed and captures.

### Next

1. Commit recon (`0009`/`0010` + docs).
2. Port streaming mode tables + exposure/gain/vblank → rear first light.
3. dw9718s AF (VAF l22, 0x0c).

Full write-up: [`pmos-camera-perry.md`](pmos-camera-perry.md).
