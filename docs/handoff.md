# Session handoff — perry / xylitol

> **Public build guide:** [`../README.md`](../README.md) ·
> [`flashing.md`](flashing.md) · [`blobs.md`](blobs.md) ·
> [`known-good.md`](known-good.md). This file is maintainer session state.

**Date:** 2026-07-20  
**Headline:** **LineageOS 18.1 BOOTS on perry** — UI, touch, adb, Wi-Fi, soft
navbar, **FM radio user-confirmed** (0007, RDS KMVQ-FM). SELinux Enforcing.
Camera open/still (0013); **AF broken** (no eeprom — bugreport). **RIL next.**  
**Meta-repo:** `main`  
**Lineage tree:** `~/android/lineage` (patches applied live; series in `patches/`)  
**Perry device tip:** `8c6bae3` — **0013** dw9718s_truly; **0012** sensors;
    **0011** platform  
**msm8937-common tip:** `0a23ebb` — patch **0007** (vendor.fm Iris bring-up)  
**Bugreport (AF+FM session):** `~/android/bugreports/perry/bugreport-perry_retail-RQ3A.211001.001-2026-07-20-13-20-02.zip`  
**TWRP:** on-device + `~/android/twrp` local 3.7.0_9-0 rebuild  
**Build host:** Ubuntu 26.04 LTS; `MKE2FS_CONFIG=$HOME/android/mke2fs.conf`
every build; put `prebuilts/python/linux-x86/2.7.5/bin` first on `PATH`  
**Device:** XT1765 / `ZY224TB8KZ` — booted, USB debugging on  

**Stock firmware (user-provided):**  
`~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml`  
**Unpacked tree:** `~/android/stock-perry-NCQS26.69-64-21/`  
(`mnt-system/`, `mnt-oem/`, `tree/` for extract-files; see [`blobs.md`](blobs.md))

Chronology: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## How to start the next session

**User opener (use this verbatim):**

> Read docs/handoff.md end-to-end and continue perry bring-up. Camera
> open/still works (0013); FM enable/tune works (msm8937-common 0007).
> Prefer RIL next. Stock dump at
> ~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml
> (unpacked under ~/android/stock-perry-NCQS26.69-64-21/). Staging-4.9
> is parked — do not start it unprompted.

**Agent checklist:**

1. Read this file + porting-log 2026-07-20 camera (0012/0013) + FM (0007).
2. Sanity: `qcamerasvr=running`, `dumpsys media.camera` → 2 devices;
   FM: `vendor.hw.fm.init=1` after opening FM2 with headset.
3. Next P1: **RIL / mobile network** (§1 #3). Camera AF/eeprom optional.
4. No AI co-author trailers. Sacred: no persist/modemst wipes. Never
   raw-dd sparse `vendor.img`.

---

## 0. How we got here (one paragraph)

Boot was blocked by staging-4.9 userspace vs real 3.18 kernel — fixed in
`msm8937-common/0002–0006`. Wi-Fi needed `perry_defconfig` pronto (`kernel/0003`).
Soft navbar: `qemu.hw.mainkeys=0` (`perry/0010`). Camera HAL SEGV was a
missing `camera.msm8937.so` red herring; **0011** montana platform stack
stabilized qcamerasvr. **0012** XT1765 sensors + vendor camera conf →
2 devices (EepromName omitted: montana `eeprom_process` SEGV). Open then
failed on `libactuator_dw9718s_truly.so`; **0013** aliases stock
`dw9718s` under that name → **preview + still capture work** (front+back).
FM needed missing `vendor.fm` + `vendor_fm_app` prop allows (**0007**).

**Working assumption:** check staging-4.9-isms first; for camera, packaging
before shims. Eeprom still deferred.

---

## 1. Open issues — the work queue

### P1 — next session

| # | Issue | State / next step |
|---|---|---|
| 1 | Soft navbar | **FIXED.** |
| 2 | **Camera** | **Open/still DONE (0013).** User re-confirmed. AF broken: 463× `Invalid-region size=0` in bugreport; needs eeprom. Video untested. See §1a. |
| 3 | **Mobile network / RIL** | Untouched. Stock NCQS26.69-64-21. GSM only; never touch `persist`/`modemst*`. |

### P1a — Camera (post-0013)

**Done**
- **0011:** montana platform stack; qcamerasvr stable.
- **0012:** XT1765 sensors/chromatix/actuator; vendor
  `msm8937_mot_camera_conf.xml`; EepromName omitted (SEGV workaround).
- **0013:** install `libactuator_dw9718s.so` also as
  `libactuator_dw9718s_truly.so` (`device.mk` PRODUCT_COPY_FILES). Montana
  `sensor_modules` defaults actuator vendor suffix to `_truly` when
  EEPROM module-info is missing; stock never shipped a `_truly` blob.

**Live verified (2026-07-20 after 0013 vendor flash)**
- `dumpsys media.camera`: **2 devices**; Active client Snap on 0 then 1.
- Back still: `IMG_20260720_102724.jpg` (~2.5 MB) and follow-ups.
- Front still: `mot_ov5695` open; JPEGs `IMG_20260720_102739.jpg`+.
- Transient first-open `-2` then successful CONNECT (both cameras) —
  soft race, not a hard fail.
- AF: `msm_actuator_move_focus: Invalid-region size = 0` (no OTP) —
  expected with EepromName omitted; focus-distances stay Infinity.

**User re-test + bugreport (2026-07-20 ~13:20)** — same AF failure mode
while capturing `IMG_20260720_1319*.jpg`. Path:
`~/android/bugreports/perry/bugreport-perry_retail-RQ3A.211001.001-2026-07-20-13-20-02.zip`
(not in git). See porting-log entry.

**Remaining camera**
1. Restore EepromName safely (fix montana `eeprom_process` SEGV /
   kernel `msm_eeprom_platform_probe failed 2192` / GPIO_31 CCI claim).
2. Video capture smoke test.
3. Optional: chase first-open `-2` race.

**Packaging**

| Makefile | Role |
|---|---|
| `camera-vendor.mk` | SoC platform from montana — **0011** |
| `perry-vendor.mk` | From `proprietary-files.txt` — sensors/chromatix |
| `device.mk` | Camera XMLs + **dw9718s → dw9718s_truly alias (0013)** |

### P2 — after P1 / opportunistic

| # | Issue | State |
|---|---|---|
| 4 | **FM radio** | **FIXED (0007).** User-confirmed (audio + RDS KMVQ-FM). Soft mediametrics denial. |
| 5 | Sepolicy pass | Enforcing; full `audit2allow` after camera AF/RIL/FM. |
| 6 | Hardware audit | BT, audio, sensors, GPS, FP (**egis**), vibrator, LED, SD/OTG, hotspot, MTP. |
| 7 | SystemUI one-off at first boot | Watch only if recurs. |
| 8 | Early-boot cpuset "No space left" | Harmless unless perf issues. |

### P3 — before release / daily-drive

| # | Item |
|---|---|
| 9 | fstab `encryptable=` → `forceencrypt=` |
| 10 | Drop `TARGET_KERNEL_VERSION := 4.9` lie; audit leftover 4.9-isms |
| 11 | Push xylitol; consider forking moto-msm89xx if patches keep growing |
| 12 | TWRP follow-ups (optional) |

---

## 2. Patches (`patches/`)

**perry (17.1 base):** 0001–0009 · **0010** soft navbar · **0011** camera
platform · **0012** XT1765 sensors + vendor camera conf · **0013**
dw9718s_truly alias  
**msm8937-common (18.1):** 0001–0006 · **0007** vendor.fm Iris / FM2  
**kernel msm8953 (18.1):** 0001–0003  
Meta: `config/mke2fs.conf`

0013 at perry `8c6bae3`; 0007 at msm8937-common `0a23ebb`.

**Key paths:**

| Item | Path |
|---|---|
| Handoff | `docs/handoff.md` |
| Camera 0011 | `patches/device/motorola/perry/0011-perry-ship-msm8937-camera-platform-stack-from-montana.patch` |
| Camera 0012 | `patches/device/motorola/perry/0012-perry-ship-XT1765-camera-sensors-and-vendor-camera-conf.patch` |
| Camera 0013 | `patches/device/motorola/perry/0013-perry-alias-dw9718s-actuator-as-dw9718s_truly-for-open.patch` |
| FM 0007 | `patches/device/motorola/msm8937-common/0007-msm8937-common-add-vendor.fm-Iris-bring-up-for-FM2.patch` |
| Perry device tree | `~/android/lineage/device/motorola/perry/` |
| Stock unpack | `~/android/stock-perry-NCQS26.69-64-21/` |
| Extract wrapper | `~/GitHub/xylitol/scripts/extract-perry.sh` |

---

## 3. Cheat sheet

```bash
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
export PATH="$HOME/android/lineage/prebuilts/python/linux-x86/2.7.5/bin:$PATH"
cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug

m bacon
m vendorimage -j$(nproc)

# CRITICAL: vendor.img is Android SPARSE — never raw-dd it to oem
simg2img out/target/product/perry/vendor.img /tmp/vendor-raw.img
adb reboot recovery
adb push /tmp/vendor-raw.img /sdcard/vendor-raw.img
adb shell 'umount /vendor 2>/dev/null; dd if=/sdcard/vendor-raw.img of=/dev/block/bootdevice/by-name/oem bs=1M; sync'
adb shell 'twrp mount vendor; ls /vendor/lib/libactuator_dw9718s_truly.so /vendor/etc/camera/msm8937_mot_camera_conf.xml'
adb reboot

# Camera triage
adb shell getprop init.svc.vendor.camera-provider-2-5 \
                 init.svc.cameraserver init.svc.vendor.qcamerasvr
adb shell dumpsys media.camera | head -40
adb shell ls -l /sdcard/DCIM/Camera/ | tail
adb logcat -d | grep -iE 'actuator|EEPROM|initializeImpl|CAM_Photo|PROFILE_OPEN'
```

**Sacred:** never wipe/repartition `persist` / `modemst1` / `modemst2`.  
No blobs / `out/` / Lineage tree in xylitol git. No AI co-author trailers.

---

## 4. Stock firmware dump

**Path:** `~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml`  
**Build:** `perry_tmo-user 7.1.1 NCQS26.69-64-21` (reconciled — CLAUDE.md correct).  
**Unpacked:** `~/android/stock-perry-NCQS26.69-64-21/` (`mnt-system` / `tree/system`).

Public notes: [`blobs.md`](blobs.md). Re-unpack:

```bash
./scripts/unpack-stock.sh \
  ~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml
```

---

## 5. Next-agent one-liner

Camera still (0013) + FM user-confirmed (0007, RDS). AF needs eeprom
(bugreport at ~/android/bugreports/perry/…13-20-02.zip). Next: **RIL**.
Never raw-dd sparse vendor. Sacred: no persist/modemst wipes.

---

## 6. Parked — side quests (do not start unprompted)

- **Mainline:** [msm89x7-mainline](https://github.com/msm89x7-mainline) /
  perry DTS PR [#48](https://github.com/msm89x7-mainline/linux/pull/48) —
  hardware map only.
- **staging-4.9 kernel port:** [`kernel-4.9-plan.md`](kernel-4.9-plan.md).
  Gate: 18.1 camera AF + RIL done first.
