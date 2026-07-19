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

See `manifests/perry.xml` for the local manifest (full history via
`clone-depth="0"`). Initial draft pinned all four projects to
`lineage-17.1`; repinned to `lineage-18.1` for the platform repos in the
entry below once `git compare` confirmed those branches are real.

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
