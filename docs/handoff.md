# Session handoff — perry / xylitol

**Date:** 2026-07-19 (late evening)  
**Headline:** **LineageOS 18.1 BOOTS on perry** — UI, touch, adb, **Wi-Fi working** (connects + browses on 2.4/5 GHz). SELinux Enforcing. Now in hardware bring-up / bug-fix phase.  
**Meta-repo:** `main`, many commits ahead of origin — push when ready  
**Lineage tree:** `~/android/lineage` (patches applied live; series mirrored in `patches/`)  
**TWRP tree:** `~/android/twrp` (local 3.7.0_9-0 rebuild works; shrunk img fits partition)  
**Build host:** Ubuntu 26.04 LTS; `MKE2FS_CONFIG=$HOME/android/mke2fs.conf` required for every build  
**Device:** XT1765 / `ZY224TB8KZ` — running current build, user actively using it

Chronology & full root-cause write-ups: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## 0. How we got here (one paragraph)

After the first zip built, boot was blocked by four userspace features that
the moto-msm89xx 18.1 tree wrote for its **unfinished staging-4.9 kernel**
while our real kernel is 3.18: configfs USB (kernel BUG panic at 7 s), FBE
(init reboot at 9.4 s), 4.9 vold sysfs paths, and a forced eBPF claim
(bpfloader reboot loop). Reverting each to what **official LineageOS 18.1**
ships (patches `msm8937-common/0002–0006`) produced a full boot. Wi-Fi was
then dead because `perry_defconfig` built pronto as a module nothing loads —
`kernel/0003` re-inlines it (`=y`, matching cedric); verified working.
**Working assumption for every new bug: check for a staging-4.9-ism first,
and mirror official LineageOS 18.1** (reference clones live in the session
scratchpad; re-clone `LineageOS/android_device_motorola_msm8937-common
lineage-18.1` when needed).

---

## 1. Open issues — the work queue

### P1 — next session

| # | Issue | State / next step |
|---|---|---|
| 1 | **No back/home/recents (no navigation at all)** | **Patched (perry 0010); flash verify pending.** `qemu.hw.mainkeys=0` in `vendor_prop.mk` (live tree `ad4f633`). Overlay `threebutton` already on /data. Finish/rebuild zip with py2 on PATH (`prebuilts/python/.../2.7.5/bin`), flash, confirm `getprop qemu.hw.mainkeys` → `0` + navbar visible. |
| 2 | **Camera stack crash-loops every boot** | Vendor `camera.provider@2.5-service` SEGVs (null deref) in `CameraModule::notifyDeviceStateChange` (2.5→2.4 legacy wrapper over Nougat HAL1 blobs); cameraserver aborts with it. Known issue class — needs the null-guard/shim on `notifyDeviceStateChange`. Check Lineage Gerrit / sibling trees for the standard fix; then actually test capture. |
| 3 | **Mobile network greyed out (no RIL)** | Expected — untouched phase. XT1765 `proprietary-files.txt` rewrite + blob re-extraction from device (`scripts/extract-perry.sh adb`). Stock build id conflict to resolve first: device reports `NPNS26.118-22-1`, CLAUDE.md says `NCQS26.69-64-21`. GSM only, IMEI must survive (sacred partitions). |

### P2 — after P1 / opportunistic

| # | Issue | State |
|---|---|---|
| 4 | Sepolicy pass | Enforcing already; first known denial: `hal_health_default` read on sysfs `type` files, fires every ~20 s (benign, noisy). Do a full `audit2allow` sweep once camera/RIL HALs are in their final shape. |
| 5 | Hardware audit (unverified subsystems) | BT (icon appears; untested), audio in/out, sensors, GPS, fingerprint, vibrator, LED, SD card + USB-OTG (patch 0005 should have fixed detection — verify), hotspot, MTP/file transfer. |
| 6 | SystemUI one-off crash (keyguard skipped → "boots to home screen") | Crashed once at first-boot/setup, zero deaths since; stack lost to buffer rotation. Watch on future reboots; investigate only if it recurs. |
| 7 | Early-boot cpuset write errors (`No space left on device`) | Still in logs, apparently harmless noise — revisit only if scheduling/perf problems appear. |

### P3 — before any release / daily-drive

| # | Item |
|---|---|
| 8 | Flip fstab `encryptable=` → `forceencrypt=` (bring-up choice in patch 0004; official ships forceencrypt) |
| 9 | `TARGET_KERNEL_VERSION := 4.9` in `BoardConfigCommon.mk` — cosmetic lie that kernel/0002 works around; clean up and audit for remaining 4.9-isms |
| 10 | Push xylitol to origin; consider forking moto-msm89xx repos if the patch stack keeps growing (per CLAUDE.md) |
| 11 | TWRP follow-ups (optional): newer TWRP base port, build from kernel source, automate flex wrapper |

---

## 2. Patches (`patches/`) — all `git am`-verified against fresh upstream clones

**perry (17.1 base):** 0001 Treble sepolicy/recovery · 0002 BOARD_COMMON · 0003 sepolicy/vendor · 0004 dtbtool Soong · 0005 extract harden · 0006 fingerprints HIDL root · 0007 file_contexts newline · 0008 MKE2FS ninja allowlist · 0009 VINTF kernel enforce false · **0010 soft navbar (`qemu.hw.mainkeys=0`)**  
**msm8937-common (18.1):** 0001 Android.mk perry filter · **0002/0003 USB → legacy android_usb (+recovery)** · **0004 FBE → FDE-capable fstab** · **0005 vold sysfs paths → 3.18** · **0006 drop eBPF claim**  
**kernel msm8953 (18.1):** 0001 perry_recovery_defconfig · 0002 V4L2 uapi aliases · **0003 pronto WLAN `=y`**  
Meta: `config/mke2fs.conf` (apexer).

Earlier build-path fixes (apexer, VINTF, fc_sort, …): table in porting-log, all cleared.

---

## 3. Cheat sheet

```bash
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug && m bacon

# Flash cycle (device usually in ROM with adb):
adb reboot recovery        # → TWRP (flashed on device)
adb push out/target/product/perry/lineage-18.1-*-perry.zip /sdcard/lineage.zip
adb shell twrp install /sdcard/lineage.zip && adb reboot
until adb shell getprop sys.boot_completed 2>/dev/null | grep -q 1; do sleep 3; done

# Local TWRP (shrunk img fits 16.1MB partition):
fastboot boot ~/android/recovery/twrp-perry-local-latest.img
# Rebuild: scripts/sync-twrp.sh && scripts/build-twrp.sh (py27 + flex wrapper)

# Crash forensics from TWRP:
adb pull /sys/fs/pstore/ ~/android/lineage/logs/boot/pstore-$(date +%Y%m%d-%H%M%S)/

# If stuck in fastboot:
fastboot getvar reason && fastboot oem fb_mode_clear && fastboot reboot

# Blob extraction (phone in system mode):
bash ~/GitHub/xylitol/scripts/extract-perry.sh adb
```

**Sacred:** never wipe/repartition `persist` / `modemst1` / `modemst2`. No blobs / `out/` / Lineage tree in xylitol git. No Claude co-author trailers on commits.

---

## 4. Next-agent opener

> Flash the 0010 navbar build when `m bacon` finishes; verify soft nav.
> Then P1-#2 (camera `notifyDeviceStateChange` shim). Check every new
> bug against official LineageOS 18.1 first — staging-4.9 mismatch is
> 5-for-5 so far. Log every fix in porting-log; export tree changes to
> `patches/`.
