# Session handoff — perry / xylitol

**Date:** 2026-07-19 (evening; TWRP side quest **done for rebuild**; LOS USB panic **fix in tree, rebuild pending**)  
**Meta-repo:** `main` — check `git status` (likely ahead of origin; push when ready)  
**Lineage tree:** `~/android/lineage`  
**TWRP tree:** `~/android/twrp` (Omni 7.1 / TeamWin perry)  
**Build host:** Ubuntu **26.04** LTS; host e2fsprogs **1.47.2**  
**Device:** XT1765 / `ZY224TB8KZ` — last verified in **locally built TWRP** (`3.7.0_9-0`, `eng.aneesh.20260719.191216`)

Chronology: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## 0. Current focus

**TWRP side quest: local rebuild works.** Prefer `fastboot boot ~/android/recovery/twrp-perry-local-latest.img` (do **not** flash — image is ~17.4 MB, recovery partition is **16.1 MB** / `0x1019000`; same as official dl.twrp.me perry img).

**LOS USB panic: root-caused and fixed in tree (2026-07-19).** Configfs userspace was a moto-msm89xx addition with no kernel support; reverted to legacy `android_usb` mirroring official LineageOS 18.1, as `patches/device/motorola/msm8937-common/0002`–`0003` (details §3 + porting-log). Applied in live common tree; series `git am`-verified on fresh upstream clone. **Next: `m installclean` + `m bacon`, flash zip via TWRP, expect `18d1:*` during boot.** The recovery half (0003) should also fix LOS recovery's dead adb.

### TWRP rebuild (verified 2026-07-19)

| Item | Detail |
|---|---|
| Recipe | Official Jenkins `perry-prod`: Omni **7.1.2**, `lunch omni_perry-eng`, `make recoveryimage`, prebuilt kernel |
| Manifest | `manifests/twrp-perry.xml` → TeamWin `android_device_motorola_perry` @ `android-7.1` |
| Sync/build | `scripts/sync-twrp.sh` then `scripts/build-twrp.sh` |
| Output | `~/android/recovery/twrp-perry-local-latest.img` (+ timestamped copy) |
| Version props | `ro.twrp.version=3.7.0_9-0`, `omni_perry-eng 7.1.2 NJH47F eng.aneesh.… test-keys` |
| Verify | `fastboot boot …` → adb `recovery`, USB `18d1:4ee2`, pstore readable |

**Ubuntu 26.04 host fixes required (already applied on this machine):**

1. **OpenJDK 8** — `sudo apt install openjdk-8-jdk-headless`
2. **Python 2.7** as `python` — micromamba env `~/android/mamba/envs/py27` (`python=2.7` from conda-forge). Omni `build/tools/*.py` are py2; system has only 3.14.
3. **flex wrapper** — Omni `prebuilts/misc/linux-x86/flex/flex-2.5.39` aborts on glibc 2.43+ (`_nl_intern_locale_data`). Replaced with a shell wrapper that `exec`s `/usr/bin/flex` under `LC_ALL=C`. Original saved as `flex-2.5.39.broken`.
4. **Size assert** — `make` fails at the end (`recovery.img too large`) but **still writes** the img. Official download is the **same byte size** (17412096). `build-twrp.sh` treats existing img as success. Use **`fastboot boot` only** until/unless someone shrinks the ramdisk or confirms a larger partition.

**Not done (optional follow-ups):** port perry DT to newer TWRP base (twrp-9.0/12.1 AOSP minimal); build from kernel source (`WITH_KERNEL_SOURCE=true`); shrink image to fit flash; automate flex wrapper in sync script.

---

## 1. Phase

| Phase | Status |
|---|---|
| LOS 18.1 ceiling / manifest / sync / env | **Done** |
| Perry device + kernel patches | **Done** (applied in live tree; see §6) |
| Full `m bacon` → zip | **Done** — `lineage-18.1-20260720-UNOFFICIAL-perry.zip` (~700 MB) |
| Flash / first boot | **Fix in tree, rebuild pending** — USB panic root-caused, legacy-android_usb patches 0002/0003 applied; needs `m bacon` + reflash |
| XT1765 proprietary rewrite | **Not done** |
| SELinux denial loop | **Not started** (never reaches userspace far enough) |
| Latest TWRP for perry | **Done** — local 3.7.0_9-0 rebuild boots via `fastboot boot` |

**Goal (main):** LineageOS **18.1** for XT1765 perry only.  
**TWRP:** maintainable rebuild path in xylitol scripts; use for pstore / sideload while fixing LOS USB panic.

---

## 2. Do this first when resuming LOS boot

1. Keep phone recoverable: **TWRP via `fastboot boot`**, never wipe `persist` / `modemst1` / `modemst2`.
2. Fix USB panic (see §3) — pick one approach, patch, rebuild `boot.img` / zip, reflash boot (or full zip).
3. Re-pull pstore after each attempt:
   ```bash
   adb pull /sys/fs/pstore/ ~/android/lineage/logs/boot/pstore-$(date +%Y%m%d-%H%M%S)/
   ```
4. Only after a panic-free boot: `adb logcat` + SELinux denial loop.

Do **not** re-run `apply-patches.sh` unless perry/common/kernel were reset to upstream.

---

## 3. LOS blocker — kernel panic (USB) — **FIXED IN TREE, rebuild pending**

**Resolution (2026-07-19):** research answered §"Research topics" #1–3 — siblings do *not* enable configfs (all moto-msm89xx defconfigs are `G_ANDROID`-only, no branch ever enabled `CONFIG_USB_CONFIGFS`); the configfs userspace was moto-msm89xx commit `e8faebe` with no kernel counterpart; the cmdline flag comes from our boot.img, not the bootloader. Official LineageOS 18.1 msm8937-common ships the legacy path and boots this kernel family. Fix **B** implemented at common level as patches `msm8937-common/0002`–`0003` (legacy `init.mmi.usb.rc` from official, cmdline flag dropped, recovery `sys.usb.configfs=1` revert). Full detail in porting-log. Symptom/panic-chain sections kept below for reference until a panic-free boot confirms.

### Symptom

- Screen: power on → **"N/A"** top-left → blank → reboot loop.
- USB during ROM boot: **no adb**, no Google gadget IDs — only brief absences then sometimes fastboot.
- `ro.boot.bootreason` / annotate: **`kernel_panic`**.
- Built kernel in panic log: `3.18.140-perf-gbbf6519df5ce #6` (`aneesh@karli`, 2026-07-19).

### Earlier red herring (cleared)

Fastboot initially reported:

`reason: UTAG "bootmode" configured as fastboot`

Cleared with `fastboot oem fb_mode_clear` (OKAY). After that the device **did** attempt real ROM boots (N/A loop) instead of forced fastboot. If you land in fastboot again, re-check `fastboot getvar reason` and clear if needed.

### Panic chain (from pstore `console-ramoops`)

At ~7.1s, `init` runs `/vendor/etc/init/hw/init.msm.usb.configfs.rc`:

1. `mount configfs none /config` → **failed: Device or resource busy**
2. `mkdir …/functions/mtp.gs0` / `accessory.gs2` → **Device or resource busy**; MTP/accessory gadget init errors
3. WARNING: `sysfs: cannot create duplicate filename '/devices/virtual/android_usb/android0/f_audio_source/pcm'`  
   (`audio_source_alloc_inst` ← `function_make` ← configfs `mkdir`)
4. **`kernel BUG at fs/sysfs/file.c:281`** — `BUG_ON(!kobj || !kobj->sd || !attr)` in `sysfs_create_file_ns` (NULL `kobj`, `x0 == 0`)
5. `Internal error: Oops - BUG` then **`Kernel panic - not syncing: Fatal exception`**

### Why (mismatch)

| Layer | Setting |
|---|---|
| Common device tree | `BOARD_KERNEL_CMDLINE` includes `androidboot.usbconfigfs=true` (`msm8937-common/BoardConfigCommon.mk`) |
| Common init | ships + imports `init.msm.usb.configfs.rc` |
| Built `perry_defconfig` | `# CONFIG_USB_CONFIGFS is not set` · `CONFIG_USB_G_ANDROID=y` |

18.1 userspace assumes **configfs USB**; perry’s 3.18 kernel still uses legacy **`android_usb` / `G_ANDROID`**. Configfs mkdir paths call into legacy function allocators → duplicate sysfs → BUG → panic. Same stack is why **LOS `recovery.img` also never enumerated adb** (`fastboot boot` of tree recovery stayed silent). Official TWRP (`omni_perry`) has a working USB stack and was usable for pstore pull.

Sibling `*_defconfig`s in this kernel repo also have `# CONFIG_USB_CONFIGFS is not set` — **research whether cedric/hannah 18.1 actually boot with this cmdline** or carry out-of-tree USB patches we missed.

### Expected fixes (pick / confirm via research)

**A. Kernel: enable USB configfs (preferred if siblings do this)**  
- Enable `CONFIG_USB_CONFIGFS` (+ needed `CONFIG_USB_CONFIGFS_*` functions) in `perry_defconfig` / `perry_recovery_defconfig`.  
- Likely need to reconcile with `CONFIG_USB_G_ANDROID` (disable or gate so both don’t register the same functions).  
- Rebuild kernel / `boot.img`, retest; confirm adb enumerates (`18d1:*`) before zygote.

**B. Device: stay on legacy android_usb (faster experiment)**  
- Perry override: drop `androidboot.usbconfigfs=true` from cmdline (don’t inherit common’s flag).  
- Stop importing / installing `init.msm.usb.configfs.rc` for perry (or no-op it).  
- Rely on `init.usb.rc` + `G_ANDROID`.  
- May be enough to stop the panic; confirm LOS 18.1 `adbd` still works with legacy path.

**C. Init hardening (complementary)**  
- Make configfs USB setup conditional on kernel support / property, so missing configfs doesn’t BUG.  
- Still need A or B for a real gadget.

### Research topics (LOS — do before / while fixing)

1. How did **cedric/hannah** 18.1 on moto-msm89xx handle USB — defconfig diff, cmdline, init overrides, kernel commits?
2. Qualcomm 3.18 + Android 11: known **`CONFIG_USB_CONFIGFS` vs `G_ANDROID`** porting notes / Lineage Gerrit.
3. Whether `androidboot.usbconfigfs=true` is set from bootloader/DT elsewhere (not only BoardConfig).
4. After USB fixed: early **cpuset** errors in the same log (`couldn't write … /dev/cpuset/…: No space left on device`, copy cpus → Invalid argument) — noise vs real follow-on?
5. XT1765 **`proprietary-files.txt`** rewrite; stock build id conflict (`NPNS26.118-22-1` on adb vs `NCQS26.69-64-21` in CLAUDE.md).
6. SELinux denial loop once past panic.

---

## 4. Logs & artifacts accessed this session

All under host paths (not in xylitol git):

### Build (`~/android/lineage/logs/`)

| Log | Result |
|---|---|
| `brunch-perry-20260719-172106.log` | ART APEX `orphan_file` failure |
| `brunch-perry-20260719-175342.log` | same / related apexer |
| `brunch-perry-20260719-175705.log` | ART OK after MKE2FS; then VINTF kernel 3.18 fail |
| `brunch-perry-20260719-180437.log` | **`BACON_RC=0`** — first successful zip |

Zip: `out/target/product/perry/lineage-18.1-20260720-UNOFFICIAL-perry.zip`

### Boot / USB watches (`~/android/lineage/logs/boot/`)

| Artifact | What it showed |
|---|---|
| `usb-*.log` / `adb-events-*.log` / `watch*.events` | ROM boot: **never** adb; only `22b8:2e80` fastboot flickers |
| `fastboot-full-20260719-183347.txt` | UTAG bootmode=fastboot; unlocked; XT1765; BA.34 |
| `fb_mode_clear-20260719-183518.txt` | `oem fb_mode_clear` OKAY |
| `pre-recovery-20260719-184616.txt` | `fastboot boot` LOS recovery — no adb after |
| **`twrp-20260719-185648.*`** | Successful TWRP adb session |
| **`twrp-20260719-185648.pstore/`** | **Smoking gun** — see below |

### Pstore (critical)

`~/android/lineage/logs/boot/twrp-20260719-185648.pstore/`

| File | Role |
|---|---|
| `annotate-ramoops-0` | Kernel version, `Last boot reason: kernel_panic` |
| `console-ramoops` | Full console including USB WARN + BUG + panic |
| `dmesg-ramoops-0` | Parallel dmesg dump (same panic) |

Also: `twrp-20260719-185648.dump.txt` (combined adb dump). `/proc/last_kmsg` **absent** on this TWRP; pstore is the right source.

### Downloaded recovery (for side quest)

`~/android/recovery/twrp-3.7.0_9-0-perry.img` — official dl.twrp.me **3.7.0_9-0** (~17 MB).  
Need referer/cookies to download (`curl -e https://dl.twrp.me/perry/ …`). Device was already on an older **omni_perry** TWRP when pstore was pulled.

---

## 5. Fixed earlier (build path — cleared)

| Stage | Failure | Fix |
|---|---|---|
| extract | Common vendor wiped | git restore + `scripts/extract-perry.sh` |
| makefile | recovery updater / perry filter | `msm8937-common/0001` |
| Soong | dtbtool host rule | `perry/0004` |
| `145405` | OMX V4L2 undeclared macros | `kernel/0002` |
| `154117` | fingerprints HIDL → montana path | `perry/0006` |
| `160541` | `fc_sort` on `file_contexts` | `perry/0007` |
| sync | `clone-depth="0"` | dropped; sync.sh unshallows |
| apexer | `orphan_file` | `config/mke2fs.conf` + `MKE2FS_CONFIG` + `perry/0008` ninja allowlist |
| OTA VINTF | no kernel entry for 3.18 @ FCM 4 | `perry/0009` `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` |

---

## 6. Patches (`patches/`)

**perry:** 0001 Treble sepolicy/recovery · 0002 BOARD_COMMON · 0003 sepolicy/vendor · 0004 dtbtool Soong · 0005 extract harden · 0006 fingerprints HIDL root · 0007 file_contexts newline · **0008** `MKE2FS_CONFIG` ninja allowlist · **0009** VINTF kernel enforce false  

**msm8937-common:** 0001 Android.mk perry filter · **0002** legacy android_usb init (revert configfs userspace, official 18.1 `init.mmi.usb.rc`) · **0003** recovery `sys.usb.configfs` revert  

**kernel msm8953:** 0001 perry_recovery_defconfig · 0002 V4L2 uapi aliases  

Plus meta: `config/mke2fs.conf` for apexer.

All known blockers have drafted patches; nothing outstanding until the post-USB-fix boot attempt (SELinux loop expected next).

---

## 7. Cheat sheet

```bash
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug && m bacon

# Boot / flash local TWRP (shrunk BoardConfig — fits 16.1MB partition)
fastboot boot ~/android/recovery/twrp-perry-local-latest.img
# or permanently:
#   fastboot flash recovery ~/android/recovery/twrp-perry-local-latest.img
# Rebuild: scripts/sync-twrp.sh && scripts/build-twrp.sh
# Shrink patch: patches/twrp/device/motorola/perry/0001-...

# After a panic boot, from TWRP:
adb pull /sys/fs/pstore/ ~/android/lineage/logs/boot/pstore-$(date +%Y%m%d-%H%M%S)/

# If stuck forced in fastboot:
fastboot getvar reason
fastboot oem fb_mode_clear
fastboot reboot

bash ~/GitHub/xylitol/scripts/extract-perry.sh adb   # phone in system mode
```

**Sacred:** never wipe `persist` / `modemst1` / `modemst2`. No blobs/`out/` in xylitol.

---

## 8. Next-agent openers

**LOS boot (main line):**

> Read `docs/handoff.md` §3. Panic is USB configfs vs `G_ANDROID` at ~7s — pstore under `logs/boot/twrp-20260719-185648.pstore/`. Implement fix A or B, rebuild boot, re-pull pstore via local TWRP (`fastboot boot ~/android/recovery/twrp-perry-local-latest.img`). Update handoff/porting-log.

**TWRP rebuild:**

> Tree at `~/android/twrp`. `scripts/build-twrp.sh` (needs py27 on PATH + flex wrapper). Output: `~/android/recovery/twrp-perry-local-latest.img`. Do not flash until image fits `0x1019000` or user accepts risk.
