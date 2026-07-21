# postmarketOS on perry — execution runbook (phases C–F)

**Date:** 2026-07-20  
**Audience:** executor agents. This file is self-contained: it assumes you
have NOT read the rest of the repo. Plan/rationale lives in
[`pmos-perry.md`](pmos-perry.md); this file is the *do* list.
Do not deviate from gates marked **GATE** without asking the user.

## 0. Ground rules (read first)

- Device: Moto E4 **XT1765** (`perry`, serial `ZY224TB8KZ`), **MSM8917**
  (wiki claims MSM8920 — ours is 8917). Bootloader unlocked. Currently
  runs our LineageOS 18.1 build — that is the primary track; pmOS is a
  side quest and must be **fully reversible**.
- **SACRED partitions — never wipe, flash, or repartition:** `persist`,
  `modemst1`, `modemst2` (EFS/IMEI). If any tool or step could touch
  them, STOP and ask the user. `pmbootstrap flasher` commands listed
  here touch only `boot` and `userdata`.
- Host: the Ubuntu 26.04 side of the dual-boot build box only. Never macOS.
- pmbootstrap 3.11.1: `~/pmos/pmbootstrap`, on PATH via `~/bin/pmbootstrap`
  (`export PATH="$HOME/bin:$PATH"`). Config: `~/.config/pmbootstrap_v3.cfg`
  (workdir `~/pmos/work`, channel systemd-edge, device `qcom-msm89x7`,
  UI console, user `aneesh`, hostname `perry`).
- Never commit into xylitol: proprietary firmware, chroots, built images.
  Xylitol carries only patches/APKBUILD overlay (`pmos/`) + docs.
- Log every completed phase + result in `docs/porting-log.md` (dated) and
  update the checkboxes here.

## 1. Phase C — kernel package with perry DTB (done)

Upstream `linux-postmarketos-qcom-msm89x7` has no perry DTB. The xylitol
overlay (`pmos/linux-postmarketos-qcom-msm89x7/`) carries PR #48
(msm89x7-mainline/linux — perry DTS, MSM8920 support, rmi_i2c reset GPIO)
rebased onto **v7.0.9-r0**, plus the Tianma 499v1 panel driver from
linux-panel-drivers#6, as pkgrel=1 with
`CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V1_TIANMA=m`.

State: overlay applied to live pmaports
(`~/pmos/work/cache_git/pmaports/device/testing/linux-postmarketos-qcom-msm89x7`),
checksums done; apk built and consumed by C4 install.

- [x] **C1. Build completes** — done 2026-07-20 15:32
  (`kernel-build-2.log`; first attempt failed, see below)
  ```bash
  set -o pipefail   # tee otherwise masks pmbootstrap failures
  export PATH="$HOME/bin:$PATH"
  pmbootstrap build --arch aarch64 linux-postmarketos-qcom-msm89x7 \
    2>&1 | tee ~/pmos/logs/kernel-build.log
  ```
  On any "completed" build, still confirm the apk exists (C2) — do not
  trust the exit status of a piped command alone. Real errors are in
  `~/pmos/work/log.txt`.
  Known transient failure: strict-mode zap dying on
  `umount .../chroot_native/proc: target is busy` — check
  `mount | grep pmos` for stragglers, `sudo umount -l` them, retry.
  Known fixed failure (2026-07-20): panel patch 0004 originally used the
  removed `mipi_dsi_dcs_write_seq` API; converted to the
  `mipi_dsi_multi_context` style matching sibling panels in
  `drivers/gpu/drm/panel/msm89x7-generated/`. If future kernel bumps
  break the panel again, diff against a compiling sibling
  (`panel-motorola-montana-r63350-tianma.c`) first.
  If a *compile* error occurs in patches 0001–0004, do NOT hand-edit the
  live pmaports copy — fix in `pmos/linux-postmarketos-qcom-msm89x7/`,
  re-run `scripts/pmos-apply-perry-kernel.sh`, re-checksum, rebuild.

- [x] **C2. Verify the package ships the perry DTB + panel module** —
  verified 2026-07-20: apk (26.8 MB) contains
  `boot/dtbs/qcom/msm8917-motorola-perry.dtb` (+ the 8920 variant) and
  `panel-motorola-perry-499v1-tianma.ko.zst`.
  ```bash
  APK=$(find ~/pmos/work/packages -name 'linux-postmarketos-qcom-msm89x7-7.0.9-r1.apk')
  tar tzf "$APK" | grep -E 'msm8917-motorola-perry.dtb|perry.*tianma|panel.*perry'
  ```
  Required: `boot/dtbs/qcom/msm8917-motorola-perry.dtb`.
  Required: the Tianma panel module (`*perry-499v1-tianma*.ko*`) under
  `usr/lib/modules/`. If the DTB is missing, the perry DTS didn't get
  wired into the Makefile — inspect patch 0003's
  `arch/arm64/boot/dts/qcom/Makefile` hunk.

## 2. Phase C½ — host-side image build (no device contact)

- [x] **C3.** `pmbootstrap config ssh_keys True` — done 2026-07-20.
  Host had no `~/.ssh/*.pub`; generated `~/.ssh/id_ed25519`
  (`aneesh@buildhost-perry-pmos`), then flipped config. Keys are baked
  into the install image at fill time (not the rootfs chroot).
- [x] **C4.** `pmbootstrap install` — done 2026-07-20 (~41 min;
  `~/pmos/logs/install.log`). Built systemd-edge/systemd under qemu
  (~38 min), then rootfs. User password: **set** (dummy via
  `--password`; prefer SSH key). Confirmed
  `(  4/263) Installing linux-postmarketos-qcom-msm89x7 (7.0.9-r1)`.
  Rootfs also has `msm8917-motorola-perry.dtb` + Tianma panel module.
- [x] **C5.** `pmbootstrap export` — done 2026-07-20
  (`~/pmos/logs/export.log`). Symlinks in `/tmp/postmarketOS-export/`:
  | Artifact | Size |
  |---|---|
  | `lk2nd.img` | 321 552 B (~314 KiB) |
  | `qcom-msm89x7.img` (combined boot+root) | 1 377 828 864 B (~1.28 GiB) |
  | `vmlinuz` | ~9.4 MiB |
  | `initramfs` | ~13.1 MiB |
  | `dtbs/msm8917-motorola-perry.dtb` | 50 523 B |
  Some export links (`boot.img`, split `-boot`/`-root`, recovery zip)
  are broken/unused on this flash path — ignore; flasher uses
  `lk2nd.img` + the combined rootfs image.

**GATE:** Phase C½ was host-only (cleared). Phase D complete — see §3.
**Next:** Phase E needs **explicit user go-ahead**.

## 3. Phase D — reversible smoke test (`fastboot boot`, no flashing) — DONE

Prereqs / backups — all must be true before proceeding:

- [x] **D1. Lineage boot.img copy exists off-device.** Verified 2026-07-20:
  SHA-256 `fe8529e0…` of
  `~/android/backups/perry/lineage-boot-2026-07-20.img` matches the
  first 11 597 824 B of the flashed `boot` partition (also
  `lineage-boot-latest.img` in same dir).
- [x] **D2. Fresh TWRP backup** of boot + data (excl. storage) pulled to
  host: `~/android/backups/perry/twrp-pmos-pre-D-20260720-1656/`
  (273 MB). Also pulled `/sdcard` media + `lineage.zip` to
  `~/android/backups/perry/sdcard-pre-D/` (userdata wipe in E would
  destroy these). Skipped `vendor-new.img` (rebuildable). Sacred
  partitions not touched.
- [x] **D3. Battery ≥ 50%.** Was **99%** in TWRP.

Smoke test (this device already proved `fastboot boot` works — we use it
for TWRP):

- [x] **D4.** From TWRP: `adb reboot bootloader`. Stock fastboot:
  `product: perry`, `version-bootloader: moto-msm8917-BA.34`,
  serial `ZY224TB8KZ`.
- [x] **D5.** `fastboot boot /tmp/postmarketOS-export/lk2nd.img` —
  OKAY; device re-enumerated into lk2nd fastboot (no flash).
- [x] **D6.** `fastboot getvar all` saved to
  `~/android/backups/perry/lk2nd-getvar-all.txt`. Key lines:
  - `lk2nd:device:perry` ✅
  - `lk2nd:version:22.0-r2-postmarketos`
  - `lk2nd:bootloader:0xBA34`
  - `product:lk2nd-msm8952` (family string — fine)
  - `serialno:ZY224TB8KZ`
  - **`lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`** ⚠️
    Our DTS/panel carry is **Tianma** 499v1; this unit is **Ofilm**
    499. Expect possible black screen on first pmOS boot (USB net
    still the debug path). Generate/ship an Ofilm panel driver before
    or right after E if display is dead.
- [x] **D7.** `fastboot reboot` → Lineage booted normally
  (`sys.boot_completed=1`,
  `lineage_perry-userdebug 11 RQ3A.211001.001 eng.aneesh.20260719.193203`).
  Nothing was flashed; reversibility confirmed.

**GATE:** If D5 shows a black screen or D6 misdetects the board, STOP.
Collect what's visible, reboot to Lineage, report. Do not proceed to E.
**(Cleared 2026-07-20 — lk2nd ran; perry detected; Lineage intact.)**
**Next:** Phase E needs **explicit user go-ahead**. Consider generating
Ofilm panel driver first given D6 panel string.
**(2026-07-20: Ofilm driver implemented — overlay 0005/0006, pkgrel=2;
see [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) §7 and Phase D¾ below.)**

## 3¾. Phase D¾ — non-flash Ofilm panel smoke (2026-07-20)

Same reversible pattern as Phase D (`fastboot boot` only, nothing
flashed): stock aboot → `fastboot boot lk2nd.img` → from lk2nd fastboot
`fastboot boot boot.img` (7.0.9-r2 with Ofilm 499v0 driver + DTB).
Success = initramfs splash on the panel (first light) even without a
rootfs on the device; USB net at `172.16.42.1` is the fallback probe if
the screen stays dark.

- [x] **D¾1.** Rebuild + export r2 artifacts (`pmbootstrap install`,
  `pmbootstrap export`). Verified: apk ships
  `panel-motorola-perry-499v0-ofilm.ko.zst`; perry DTB has the ofilm
  compatible.
- [x] **D¾2.** `adb reboot bootloader` (from TWRP) → stock fastboot.
- [x] **D¾3.** `fastboot boot /tmp/postmarketOS-export/lk2nd.img`.
- [ ] **D¾4.** **BLOCKED 2026-07-20** — no exported boot.img exists
  (extlinux device); hand-crafted boot images (v2-dtb and appended-dtb
  v0, both offset conventions) all die pre-initramfs and watchdog-reset
  to Lineage. See porting-log entry. Not a panel failure — USB gadget
  never appears, so initramfs never ran.
- [x] **D¾5.** Eyes-on retry done (user observed): lk2nd screen →
  display off at handoff (expected; simple-framebuffer disabled, panel
  driver is initramfs module) → SoC reset (aboot "N/A") → Lineage.
  **fastboot-boot smoke is a dead end on this device; panel
  first-light defers to Phase E.** Driver untested but un-refuted.
- [x] **D¾6.** Rebooted back to Lineage; confirmed intact (multiple
  cycles). Nothing flashed.

## 4. Phase E — flash lk2nd + rootfs, first boot — **EXECUTED 2026-07-20**

**GATE CLEARED:** user opened it ("fully commit to flashing pmOS").
**The authoritative, detailed account is in
[`handoff.md`](handoff.md) "Phase E pmOS" — read that first.** Summary of
what actually happened (checkboxes reflect reality, not the original plan):

- [x] **E1.** `pmbootstrap flasher flash_lk2nd` from STOCK fastboot →
  lk2nd on `boot`. ("Image not signed or corrupt" = normal unlocked warn.)
- [x] **E2.** `fastboot reboot` + Vol-Down → lk2nd fastboot confirmed
  (`product: lk2nd-msm8952`, serial `24b071b`). **lk2nd enters fastboot
  only on Vol-Down; USB does NOT force it.**
- [x] **E3.** `pmbootstrap flasher flash_rootfs` → `userdata` (Lineage
  data wiped; covered by D2). Re-run once more after the extlinux fix.
- [~] **E4. IN PROGRESS — two boot blockers found:**
  - **Blocker A (FIXED):** lk2nd fell back to fastboot;
    `oem log` showed `The dtb-files for this device is not set` /
    `Failed to parse extlinux.conf`. Cause: `extlinux.conf` used
    `fdtdir /`, which needs an lk2nd device node perry lacks. **Fix:
    `fdt /msm8917-motorola-perry.dtb`** (explicit). lk2nd now boots the
    kernel.
  - **Blocker B (CURRENT):** kernel executes but is silent — no console
    (fb node `disabled`) + USB `dr_mode="otg"` (no gadget). Prepared a
    **DTB-only patch** (framebuffer `okay` + usb `peripheral`) for
    observability; reflash/boot pending. Full detail + reflash recipe in
    handoff "Phase E pmOS" §E-4/§E-5.
- [ ] **E5.** `ssh aneesh@172.16.42.1` once USB-net is up; record
  `uname -a`, `dmesg`, `cat /proc/device-tree/model`, panel/DRM status.

**Both current on-device fixes are image edits (lost on `pmbootstrap
install`).** Durable-overlay TODOs in handoff §E-6.

Failure paths:

- No display but USB network up → panel issue; SSH in, grab `dmesg`.
- Nothing at all → pull `sys/fs/pstore/console-ramoops` via TWRP
  (`fastboot boot twrp.img` still works from stock aboot even with lk2nd
  on boot). Record and report.
- To retry a kernel/DTB change: fix overlay → rebuild (C1–C2) →
  `pmbootstrap install` → from lk2nd fastboot re-flash rootfs (E3).

## 5. Phase F — feature audit

On a booted console image, verify and record each row in
[`pmos-perry.md`](pmos-perry.md) §7 (USB net, screen, touch, Wi-Fi, BT,
audio, GPU/3D, battery, OTG, modem calls/SMS/data, camera-expect-broken).
Useful: `wpa_cli`/NetworkManager for Wi-Fi (msm-firmware-loader should
have mounted modem/WCNSS firmware from the device's own partitions —
check `ls /lib/firmware/` and `dmesg | grep -i wcnss`). Feed results
back into §7's XT1765 column and `porting-log.md`.

Only after F: consider a UI (Phosh/Xfce) — separate decision with the
user (2 GB RAM; console first).

## 6. Rollback to LineageOS (any time)

1. Power off → Power + Vol-Down → **stock** bootloader fastboot (aboot
   is untouched by everything above).
2. `fastboot flash boot <lineage-boot.img>` (D1 artifact) — removes
   lk2nd entirely.
3. Boot TWRP (`fastboot boot twrp.img`) → restore `data` from the D2
   backup (or factory-reset data for a clean Lineage first boot).
   `system`/`oem` (vendor) were never touched by pmOS.
4. Reboot → Lineage. Sacred partitions were never in play.

## 7. Reference

| Item | Value |
|---|---|
| Kernel overlay | `pmos/linux-postmarketos-qcom-msm89x7/` (apply: `scripts/pmos-apply-perry-kernel.sh`) |
| Live pmaports pkg | `~/pmos/work/cache_git/pmaports/device/testing/linux-postmarketos-qcom-msm89x7` |
| Upstream backup of pkg | `<pkg>/.xylitol-upstream/` |
| Build log | `~/pmos/logs/kernel-build.log` |
| Export dir | `/tmp/postmarketOS-export/` |
| Generic wiki | <https://wiki.postmarketos.org/wiki/Generic_MSM89x7_(qcom-msm89x7)> |
| Perry wiki | <https://wiki.postmarketos.org/wiki/Motorola_Moto_E4_(motorola-perry)> |
| lk2nd repo (perry listed in devices.md, 8917+8920) | <https://github.com/msm8916-mainline/lk2nd> |
| DTS PR | <https://github.com/msm89x7-mainline/linux/pull/48> |
| Panel PR (Tianma) | <https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6> |
| **Ofilm research brief** | [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) |
