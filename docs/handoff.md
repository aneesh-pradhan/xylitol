# Session handoff — perry / xylitol

**Date:** 2026-07-19 (end of day; pick up fresh next session)  
**Meta-repo:** `main` tip includes handoff + build-fix commits (may be ahead of origin — push if needed)  
**Lineage tree:** `~/android/lineage` (not in this repo)  
**Build host:** Ubuntu **26.04** LTS (`resolute`), host `mke2fs` **1.47.2**

Detailed chronology: [`porting-log.md`](porting-log.md). Project rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## 1. Project phase (where we are)

| Phase | Status |
|---|---|
| Evidence / ceiling (LOS 18.1) | **Done** |
| Manifest + sync + env (26.04) | **Done** |
| Perry 17.1→18.1 device/kernel patches | **Done** (applied in live tree) |
| First full `m bacon` | **Blocked** — failed @ **94%** (see §5) |
| Flashable zip | **None yet** |
| XT1765 proprietary rewrite | **Not done** |
| Boot / SELinux | **Not started** |

**One-line summary:** First successful full build is **close but not done**. Multiple Soong/device blockers were fixed; the latest bacon died packaging the ART APEX because Ubuntu 26.04’s e2fsprogs defaults (`orphan_file`) break Lineage 18.1’s bundled `mke2fs` 1.45.4 via `apexer`.

**Goal:** LineageOS **18.1** for XT1765 perry. Do not pivot to 19.0+.

---

## 2. First actions next session

```bash
# Confirm no build running; read the failure
pgrep -af 'soong_ui|ninja.*bacon' || echo 'idle'
tail -80 ~/android/lineage/logs/brunch-perry-20260719-172106.log

# Then fix the apexer/mke2fs orphan_file issue (research in §6), then:
cd ~/android/lineage
source build/envsetup.sh && lunch lineage_perry-userdebug
m bacon 2>&1 | tee logs/brunch-perry-$(date +%Y%m%d-%H%M%S).log
```

Do **not** re-run `apply-patches.sh` unless device/kernel/common repos were reset.

---

## 3. CURRENT blocking error (must fix first)

### ART APEX / `mke2fs` + `orphan_file` (Ubuntu 26.04)

- **Log:** `~/android/lineage/logs/brunch-perry-20260719-172106.log`
- **Progress at fail:** ~**94%** (9350+/9895 incremental graph)
- **FAILED target:** `com.android.art.release.apex.unsigned` (`apexer` → image payload)
- **Symptom:**
  ```
  Invalid filesystem option set: has_journal,extent,...,orphan_file
  AssertionError: Failed to execute: out/soong/host/linux-x86/bin/mke2fs -O ^has_journal ...
  ```
- **Cause:** Host `/etc/mke2fs.conf` (e2fsprogs **1.47.2**) enables ext4 feature **`orphan_file`**. Lineage’s tree `mke2fs` is **1.45.4** and rejects that feature set when creating the APEX ext4 image.
- **Not a perry device-tree bug** — host toolchain / LOS 18.1 vs new Ubuntu.

**Likely fix directions to research (pick one, document in porting-log):**

1. Point build at a config without `orphan_file`, e.g. copy `/etc/mke2fs.conf`, strip `orphan_file`, export `MKE2FS_CONFIG=/path/to/mke2fs-no-orphan.conf` before `m bacon`.
2. Patch or wrap the soong `mke2fs` invocation / `apexer` (upstream LOS/Ubuntu 24+ threads often discuss this).
3. Avoid wiping `out/` — only need APEX packaging to succeed after a config fix.

After fix, resume `m bacon` (incremental should be fast to the APEX step).

---

## 4. Fixed this session (no longer blocking)

| When (log) | Failure | Fix (xylitol patch / action) |
|---|---|---|
| extract | Common APKs wiped | Restore `vendor/motorola` git; use `scripts/extract-perry.sh` |
| early | `librecovery_updater_motorola` missing | `patches/.../msm8937-common/0001` (add perry to Android.mk filter) |
| early | dtbtool `BUILD_HOST_EXECUTABLE` | `perry/0004` Soong |
| `145405` ~40% | OMX `V4L2_QCOM_CMD_FLUSH` / `LEVEL_UNKNOWN` | `kernel/.../0002` uapi aliases |
| `154117` ~36% | `hidl-gen` path `montana/interfaces` | `perry/0006` → perry interfaces |
| `160541` ~85% | `fc_sort` / vendor `file_contexts` | `perry/0007` trailing newline on `sepolicy/vendor/file_contexts` |
| sync | `clone-depth="0"` rejected | Dropped attribute; `sync.sh` unshallows four repos |

Also: `perry_recovery_defconfig` added (`kernel/0001`); extract hardened (`perry/0005`).

---

## 5. Still open (not today’s bacon stopper, but next)

### A. `proprietary-files.txt` montana-contaminated

- ~**26/99** blobs under `vendor/motorola/perry/proprietary/`
- List still has FPC / montana touch / wrong chromatix names; device is stock Nougat (`NPNS26.118-22-1` seen on adb; CLAUDE.md also cites `NCQS26.69-64-21` — **reconcile**)
- Can cause later copy-file failures or broken camera/FP at runtime even after zip builds
- Re-extract only via `./scripts/extract-perry.sh adb` (never wipe common)

### B. After first zip

- `fastboot boot` TWRP; never wipe `persist` / `modemst1` / `modemst2`
- Boot logcat / `last_kmsg`; SELinux denial loop → `sepolicy/vendor` patches

### C. Meta

- Push any unpushed xylitol commits (`git status -sb`)
- Cursor `Co-authored-by` trailer: disable `attributeCommitsToAgent` in Cursor CLI config; contributors graph refreshed via main↔main1 rename earlier

---

## 6. Research agenda (ordered)

1. **Unblock APEX:** `orphan_file` / `MKE2FS_CONFIG` on Ubuntu 26.04 + LOS 18.1 (search Lineage/XDA/AOSP for “mke2fs orphan_file apexer”).
2. **Finish bacon** → locate `out/target/product/perry/lineage-*.zip`.
3. **Rewrite `proprietary-files.txt`** from live XT1765 stock inventory (egis FP, ov5695 `l5695fa0`, etc.).
4. Optional: more `TARGET_KERNEL_VERSION=4.9` vs 3.18 uapi gaps beyond the two V4L2 macros already shimmed.

---

## 7. Patch inventory (`patches/`)

### `device/motorola/perry/`

| # | Subject |
|---|---|
| 0001 | Treble vendor sepolicy + recovery config |
| 0002 | `BOARD_COMMON` for extract |
| 0003 | `sepolicy/` → `sepolicy/vendor/` |
| 0004 | dtbtool → Soong |
| 0005 | Harden extract for partial XT1765 sets |
| 0006 | `com.fingerprints` HIDL root → perry interfaces |
| 0007 | Trailing newline on `file_contexts` |

### `device/motorola/msm8937-common/`

| # | Subject |
|---|---|
| 0001 | Include perry in Android.mk device filter |

### `kernel/motorola/msm8953/`

| # | Subject |
|---|---|
| 0001 | `perry_recovery_defconfig` (WLAN stripped) |
| 0002 | V4L2 uapi aliases for CAF OMX |

Live tree already has these applied (detached HEADs). Re-apply only after reset.

---

## 8. Resume cheat sheet

```bash
. /etc/os-release; echo "$PRETTY_NAME"   # Ubuntu 26.04

# Build
cd ~/android/lineage
source build/envsetup.sh && lunch lineage_perry-userdebug
# AFTER fixing MKE2FS_CONFIG / orphan_file:
m bacon 2>&1 | tee logs/brunch-perry-$(date +%Y%m%d-%H%M%S).log

# Perry-only blobs (phone in *system*, adb state=device)
bash ~/GitHub/xylitol/scripts/extract-perry.sh adb

# If common proprietary wiped
cd ~/android/lineage/vendor/motorola && git checkout HEAD -- msm8937-common/proprietary/
```

| Task | Device mode |
|---|---|
| extract | System |
| bacon | Host only |
| flash / `fastboot boot twrp` | Fastboot |

---

## 9. Sacred

- Never wipe `persist`, `modemst1`, `modemst2`
- Never commit Lineage tree / `out/` / blobs into xylitol
- Prefer `fastboot boot twrp.img` until ROM stable
- No Cursor/Claude co-author on pushed commits

---

## 10. Suggested opener for next agent

> Read `docs/handoff.md`. Latest bacon failed at 94% on `com.android.art.release` apexer/`mke2fs` with `orphan_file` (Ubuntu 26.04). Fix that host-side, resume `m bacon`, then update this handoff and porting-log.
