# Session handoff — perry / xylitol

**Date:** 2026-07-20  
**Headline:** **LineageOS 18.1 BOOTS on perry** — UI, touch, adb, Wi-Fi, soft
navbar. SELinux Enforcing. Camera platform stack **verified**: qcamerasvr
`running`, zero link errors. 0 devices until XT1765 sensor blobs (stock dump).  
**Meta-repo:** `main`, ahead of origin (local docs dirty) — push when ready  
**Lineage tree:** `~/android/lineage` (patches applied live; series in `patches/`)  
**Perry device tip:** `fb53f4e` — `perry: ship msm8937 camera platform stack
from montana` (patch **0011**)  
**TWRP:** on-device + `~/android/twrp` local 3.7.0_9-0 rebuild  
**Build host:** Ubuntu 26.04 LTS; `MKE2FS_CONFIG=$HOME/android/mke2fs.conf`
every build; put `prebuilts/python/linux-x86/2.7.5/bin` first on `PATH`  
**Device:** XT1765 / `ZY224TB8KZ` — booted, USB debugging on

Chronology: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## How to start the next session

**User opener (use this verbatim):**

> Read docs/handoff.md end-to-end and continue perry camera bring-up.
> Platform stack is verified (qcamerasvr `running`, patch 0011 committed
> at `248f873`); the sole blocker is XT1765 sensor blobs. The stock
> firmware dump is at **[directory]**. The staging-4.9 kernel side quest
> is parked (docs/kernel-4.9-plan.md) — do not start it unprompted.

**Agent checklist when you see that:**

1. Read this file end-to-end, then skim camera entries in
   [`porting-log.md`](porting-log.md) (2026-07-19 → 07-20 camera
   sections; 07-20 flash-verify entry is the current state).
2. Sanity-check the device matches the handoff: `adb shell getprop
   init.svc.vendor.qcamerasvr` → `running`; `dumpsys media.camera` →
   0 devices. If it disagrees, re-triage before extracting anything.
3. Treat **`[directory]`** as the XT1765 stock 7.1.1 dump root (see §4).
   Verify it exists; read any `README.txt` for build id, and reconcile
   the NPNS26.118-22-1 (live device) vs NCQS26.69-64-21 (CLAUDE.md)
   question in the log.
4. Inventory camera blobs under the dump before extracting (§4 commands):
   imx219 / s5k4h8 / mot_ov5695 / dw9718s / chromatix.
5. Run `bash ~/GitHub/xylitol/scripts/extract-perry.sh '[directory]'` for
   perry-only blobs; rewrite `proprietary-files.txt` camera section for
   the real XT1765 sensor set; regenerate `perry-vendor.mk` via
   `setup-makefiles.sh` — never hand-edit dest paths.
6. Rebuild (`m vendorimage`), `simg2img` → TWRP `dd` to oem (§3 —
   never raw-dd the sparse image), test still + video (front + back).
   If capture dies with HAL loaded + daemon up, only then consider the
   defensive `notifyDeviceStateChange` null-guard (§1a).
7. Watch the known `msm_eeprom_platform_probe failed 2192` kernel lines
   when sensors land (OTP/eeprom → AF/AWB calibration).
8. Log decisions in `porting-log.md`; export new patches to `patches/`.
   No AI co-author trailers on commits.

If the user omits the stock path, ask for it before rewriting
`proprietary-files.txt`. Camera done → next queue items: RIL (§1 P1#3),
FM (§1 P2#4).

---

## 0. How we got here (one paragraph)

Boot was blocked by staging-4.9 userspace vs real 3.18 kernel (USB configfs,
FBE, vold sysfs, eBPF claim) — fixed in `msm8937-common/0002–0006`. Wi-Fi
needed `perry_defconfig` pronto `=y` (`kernel/0003`). Soft navbar needed
`qemu.hw.mainkeys=0` (`perry/0010`; soc_id 303 not in init.qcom.sh allowlist).
Camera “SEGV in notifyDeviceStateChange” was a **red herring**: primary
failure was missing `camera.msm8937.so`; SEGV was null `mModule` after init
fail because `@2.5-service` still registers. **Working assumption:** check
staging-4.9-isms first; for camera, check packaging/blobs before shims.

---

## 1. Open issues — the work queue

### P1 — next session

| # | Issue | State / next step |
|---|---|---|
| 1 | Soft navbar | **FIXED.** `qemu.hw.mainkeys=0`, threebutton overlay on. |
| 2 | **Camera** | **Platform stack verified 07-20 — see §1a.** qcamerasvr `running`, no link errors, 97 vendor tags exported. Blocks solely on stock 7.1.1 dump for imx219/s5k4h8/mot_ov5695. Then capture test. |
| 3 | **Mobile network / RIL** | Untouched for bring-up. `rild` runs; `gsm.sim.state` was ABSENT last check (confirm SIM). XT1765 `proprietary-files.txt` rewrite + stock extract. Build-id note: live device has reported `NPNS26.118-22-1`; CLAUDE.md cites `NCQS26.69-64-21` — reconcile against the stock dump. GSM only; never touch `persist`/`modemst*`. |

### P1a — Camera detail (read this)

**Done**
- Phase 0: injected montana `camera.msm8937.so`; ENOENT was also SELinux
  (`system_file` from TWRP push → getattr denied). After `vendor_file`,
  provider opened the HAL FD.
- Phase 2: `device/motorola/perry/camera-vendor.mk` + inherit from
  `device.mk` — ~94 SoC platform blobs from montana (HAL, mm-qcamera,
  MCT/ISP, jpeg, moto metadata, gralloc1, …). Patch **0011**.
- Fixed hand-trimmed `vendor/motorola/perry/perry-vendor.mk` dests:
  was `$(TARGET_COPY_OUT_VENDOR)/vendor/...` → `/vendor/vendor/lib/`
  (strip extra `vendor/`). Local only; regenerate properly when rewriting
  proprietary-files.
- **2026-07-20: gralloc1-inclusive vendor FLASHED and verified.**
  (`/tmp` raw was lost to host reboot; regenerate any time via
  `simg2img out/.../vendor.img` — the 07-19 23:21 build includes
  gralloc1.)

**Live device right now (post gralloc1 flash, 07-20)**
- `camera.msm8937.so`, `mm-qcamera-daemon`, `libgralloc1.so` on /vendor
- `init.svc.vendor.camera-provider-2-5=running`, `cameraserver=running`
- `vendor.qcamerasvr=running` — **stable**, daemon steady in `do_select`;
  zero `CANNOT LINK` in logcat. Link-dep chase is DONE.
- `dumpsys media.camera`: **0 devices** (expected — no sensor libs);
  provider exports 97 qcamera3 vendor tags
- Kernel early-boot: `msm_eeprom_platform_probe failed 2192` ×2 — watch
  when sensor libs land (OTP/eeprom → AF/AWB calibration)

**Perry sensors (from `msm8917_mot_perry_camera.xml`)**
- Back: `s5k4h8` or `imx219` (+ actuator `dw9718s` on device XML)
- Front: `mot_ov5695` / chromatix `mot_ov5695_l5695fa0`
- **Not in any moto-msm89xx vendor tree** except partial `mot_ov5695`.
  Montana leftovers (s5k3p3/s5k3p8sp) are the wrong SKU.

**Packaging architecture (do not confuse these):**

| Makefile | Role |
|---|---|
| `camera-vendor.mk` | SoC platform stack from montana (HAL, daemon, MCT/ISP, jpeg, gralloc1, …) — patch **0011** |
| `perry-vendor.mk` | Generated from `proprietary-files.txt` via `setup-makefiles.sh` — sensor/chromatix + perry-specific blobs |
| `montana-vendor.mk` | Never inherited on perry; `BoardConfigVendor.mk` include is empty |

**Packaging bugs (fixed locally or pending stock rewrite):**
1. Missing HAL: `camera.msm8937.so` never packaged → **0011** / `camera-vendor.mk`.
2. Double vendor path: hand-trimmed `perry-vendor.mk` dest
   `$(TARGET_COPY_OUT_VENDOR)/vendor/...` → **`/vendor/vendor/lib/`** — regenerate via
   `setup-makefiles.sh`, do not hand-edit.
3. Wrong sensor SKU in `proprietary-files.txt` — only **26/99** paths matched live
   XT1765 stock (porting-log). Stock dump rewrite is required for capture.

**Root cause chain (for debugging — SEGV was not primary):**
1. Primary: `hw_get_module` → `-2` because `camera.msm8937.so` missing.
2. Secondary: `@2.5-service` registers even when init fails → null `mModule` →
   SEGV at `notifyDeviceStateChange` (fault addr `0x8`).
3. TWRP inject: files as `system_file` → SELinux getattr denial → still looks
   like ENOENT until `chcon u:object_r:vendor_file:s0`.

**Next camera steps (ordered)**
1. ~~Flash latest vendor raw~~ **DONE 07-20.**
2. ~~Confirm `vendor.qcamerasvr` stays `running`~~ **DONE 07-20** — no
   further link deps.
3. Ingest stock dump from user-provided **`[directory]`** (§4): extract
   imx219/s5k4h8/dw9718s/chromatix; rewrite `proprietary-files.txt` camera
   section; regenerate `perry-vendor.mk` via `setup-makefiles.sh`.
4. Only if HAL loads and daemon is up but capture still dies: consider
   null-guard on `notifyDeviceStateChange` / don't register when
   `isInitFailed` — defensive, not the bring-up fix.
5. Test still + video, front + back.

### P2 — after P1 / opportunistic

| # | Issue | State |
|---|---|---|
| 4 | **FM radio** | Sepolicy: `get_prop(vendor_fm_app, vendor_fm_prop)`. Also live: `ctl.start` can't find `vendor.fm` service; `vendor.hw.fm.init` unset; app ANR. Fix init service + prop + sepolicy; headset as antenna. |
| 5 | Sepolicy pass | Enforcing; `hal_health` sysfs noise + FM. Full `audit2allow` after camera/RIL/FM. |
| 6 | Hardware audit | BT, audio, sensors, GPS, FP (egis, not FPC), vibrator, LED, SD/OTG, hotspot, MTP. |
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

**perry (17.1 base):** 0001–0009 as before · **0010** soft navbar ·
**0011** camera platform stack from montana (`camera-vendor.mk`)  
**msm8937-common (18.1):** 0001–0006 (USB/FBE/vold/eBPF)  
**kernel msm8953 (18.1):** 0001–0003 (recovery defconfig, V4L2, pronto `=y`)  
Meta: `config/mke2fs.conf`

0011 applied live at perry `fb53f4e`. Re-verify `git am` on fresh clone
when convenient.

**Key paths:**

| Item | Path |
|---|---|
| Handoff | `docs/handoff.md` |
| Camera patch 0011 | `patches/device/motorola/perry/0011-perry-ship-msm8937-camera-platform-stack-from-montana.patch` |
| Perry device tree | `~/android/lineage/device/motorola/perry/` |
| `camera-vendor.mk` | `~/android/lineage/device/motorola/perry/camera-vendor.mk` |
| Perry camera XML | `device/motorola/perry/configs/camera/msm8917_mot_perry_camera.xml` |
| Extract wrapper | `~/GitHub/xylitol/scripts/extract-perry.sh` |
| Vendor raw | flashed 07-20; regenerate: `simg2img out/.../vendor.img <raw>` |

---

## 3. Cheat sheet

```bash
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
export PATH="$HOME/android/lineage/prebuilts/python/linux-x86/2.7.5/bin:$PATH"
cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug

# Full ROM
m bacon

# Vendor-only (camera packaging iterates here)
m vendorimage -j$(nproc)

# CRITICAL: vendor.img is Android SPARSE — never raw-dd it to oem
simg2img out/target/product/perry/vendor.img /tmp/vendor-raw.img
# Flash via TWRP (oem == /vendor on perry; do NOT touch persist/modemst*):
adb reboot recovery
adb push /tmp/vendor-raw.img /sdcard/vendor-raw.img
adb shell 'umount /vendor 2>/dev/null; dd if=/sdcard/vendor-raw.img of=/dev/block/bootdevice/by-name/oem bs=1M; sync'
adb shell 'twrp mount vendor; ls /vendor/lib/hw/camera.msm8937.so /vendor/bin/mm-qcamera-daemon'
adb reboot

# Full zip flash
adb reboot recovery
adb push out/target/product/perry/lineage-18.1-*-perry.zip /sdcard/lineage.zip
adb shell twrp install /sdcard/lineage.zip && adb reboot

# If stuck in fastboot ("Reboot mode set to fastboot"):
fastboot getvar reason && fastboot oem fb_mode_clear && fastboot reboot

# Camera triage
adb shell getprop init.svc.vendor.camera-provider-2-5 \
                 init.svc.cameraserver init.svc.vendor.qcamerasvr
adb logcat -d | grep -iE 'CamPrvdr|CANNOT LINK|mm-qcamera|Loaded .* camera'
adb shell dumpsys media.camera | head -40

# Perry-only blob extract (does NOT wipe msm8937-common):
bash ~/GitHub/xylitol/scripts/extract-perry.sh /path/to/stock-dump
# or: bash ~/GitHub/xylitol/scripts/extract-perry.sh adb   # from running ROM only
```

**Sacred:** never wipe/repartition `persist` / `modemst1` / `modemst2`.  
No blobs / `out/` / Lineage tree in xylitol git. No AI co-author trailers.

---

## 4. Stock firmware dump — user provides path at session start

When the user says **"read the handoff; the stock firmware is at `[directory]`"**,
use that path as `STOCK=...` below. This is the main input for finishing camera
(and later RIL / FP / proprietary-files rewrite).

**Expected layout (any of these is fine — discover with `find`):**

```text
[directory]/
  README.txt          # build id, source URL, date fetched (user should add)
  boot.img            # optional
  system/             # unpacked system.img
  system/vendor/      # Nougat often nests vendor here
  vendor/             # if firmware ships a separate vendor.img extract
```

**Build-id conflict to reconcile:** live device reported `NPNS26.118-22-1`;
CLAUDE.md cites `NCQS26.69-64-21`. Record the dump's actual build id in
README and note which base the extracted blobs came from.

**Step 1 — inventory (before extract):**

```bash
STOCK='[directory]'   # replace with user path

# Camera HAL + daemon + sensor/chromatix (priority)
find "$STOCK" \( -path '*lib/hw/camera*' -o -path '*mm-qcamera*' \
  -o -iname '*imx219*' -o -iname '*s5k4h8*' -o -iname '*mot_ov5695*' \
  -o -iname '*dw9718*' -o -path '*etc/camera*' \) -type f 2>/dev/null | sort

# Later: RIL / fingerprint (do not block camera on these)
find "$STOCK" \( -iname '*ril*' -o -iname '*qcril*' \
  -o -iname '*egis*' -o -iname '*fingerprint*' \) -type f 2>/dev/null | sort
```

**Blobs we need from stock (camera-first):**

```text
**/lib/hw/camera*.so
**/lib/libmmcamera*
**/lib/libchromatix_imx219*
**/lib/libchromatix_s5k4h8*
**/lib/libchromatix_mot_ov5695*
**/lib/libactuator_dw9718*
**/lib/libmmcamera_imx219*
**/lib/libmmcamera_s5k4h8*
**/bin/mm-qcamera*
**/etc/camera/*          # if present; perry XMLs already in device tree
```

**Step 2 — extract into Lineage tree (perry-only; does not wipe common):**

```bash
bash ~/GitHub/xylitol/scripts/extract-perry.sh "$STOCK"
# or from running ROM only: bash ~/GitHub/xylitol/scripts/extract-perry.sh adb
```

**Step 3 — rewrite packaging (in `device/motorola/perry/`):**
1. Update `proprietary-files.txt` camera section for XT1765 paths found in
   `$STOCK` (drop montana s5k3p3/s5k3p8sp entries).
2. Run `./setup-makefiles.sh` to regenerate `vendor/motorola/perry/perry-vendor.mk`.
3. Keep platform stack in `camera-vendor.mk` (0011) — do not duplicate HAL/daemon
   blobs into perry-vendor unless stock differs from montana.
4. Export patch(es) to `patches/device/motorola/perry/`; log in porting-log.

**Step 4 — rebuild and flash:** `m vendorimage` (iterate) or `m bacon`; flash
vendor raw via TWRP oem (§3), then test capture.

Perry has **no GPT `vendor` partition** — Lineage mounts **oem as `/vendor`**.
Fastboot `flash vendor` fails; use oem/TWRP only.

---

## 5. Next-agent one-liner

User will open with: **read the handoff; the stock firmware is at `[directory]`.**

Then (vendor flash + qcamerasvr verify DONE 07-20): inventory + extract from
`[directory]` → rewrite `proprietary-files.txt` camera section →
`setup-makefiles.sh` → rebuild/flash → test capture. Chase any new
`CANNOT LINK` into `camera-vendor.mk` / 0011. Opportunistic: FM init+sepolicy,
RIL stock paths. Never raw-dd sparse `vendor.img`. Log + export patches.
Sacred: no persist/modemst wipes.

---

## 6. Parked — side quests (do not start unprompted)

- **Mainline:** [msm89x7-mainline](https://github.com/msm89x7-mainline) /
  perry DTS PR [#48](https://github.com/msm89x7-mainline/linux/pull/48) —
  hardware map only (WCN3660B Iris, etc.). Nothing to port into 18.1
  blob stack.
- **staging-4.9 kernel port:** recon 2026-07-20 says feasible (surfna
  4.9.112 + LOS xiaomi msm8937 4.9.337 as templates; camera blobs are
  the big risk). Phased plan: [`kernel-4.9-plan.md`](kernel-4.9-plan.md);
  recon + Gemini-doc fact-check in porting-log 2026-07-20. Gate:
  18.1 camera + RIL done first.
