# Session handoff — perry / xylitol

> **Public build guide:** [`../README.md`](../README.md) ·
> [`flashing.md`](flashing.md) · [`blobs.md`](blobs.md) ·
> [`known-good.md`](known-good.md). This file is maintainer session state.

**Date:** 2026-07-20  
**Headline:** **LineageOS 18.1 BOOTS on perry** — UI, touch, adb, Wi-Fi, soft
navbar, **FM radio user-confirmed** (0007), **camera open/still** (0011–0013;
**0015** keeps montana `sensor_modules`). **AF still broken.** SELinux
Enforcing. **RIL next** (or AF retry with a non-preview-breaking approach).  
**pmOS side quest — NOW THE ACTIVE WORK (2026-07-20):** Phase E
**FLASHED** and **BOOTING**. **Blocker B is CLEARED** — the kernel that was
"blind & mute" now boots to a full postmarketOS edge userspace
(`7.0.9-msm89x7`, **aarch64**) with USB-net + SSH (`ssh aneesh@172.16.42.1`,
sudo pw `147147`). **WiFi FIXED** (missing perry WCNSS NV blob → `-2`; dropped
perry's own NV → `wlan0` up, scans 51 APs, associates + DHCP + internet,
auto-reconnects on cold boot). Installer:
`scripts/pmos-install-wcnss-nv.sh` (runtime); **durable Wi-Fi pmaport DONE**
(`firmware-motorola-perry-nv`, PR [#2](https://github.com/aneesh-pradhan/xylitol/pull/2)).
**Ofilm 499v0 panel first-light CONFIRMED** (user-witnessed: fb static +
`perry login:` tty + backlight blink; `compatible: motorola,perry-499v0-ofilm`,
DSI-1 connected 720×1280). Full write-up:
[porting-log 2026-07-20 "pmOS BOOTS to userspace"]. **Next-to-dos board:
[§ Next to-dos](#next-to-dos-2026-07-20-end-of-session).** Ofilm panel driver
in overlay 0005/0006, kernel 7.0.9-r2. Full session log below in
[§ Phase E pmOS](#phase-e-pmos--flashed-mid-bring-up-session-2026-07-20-evening).  
**Meta-repo:** `main`  
**Lineage tree:** `~/android/lineage` (patches applied live; series in `patches/`)  
**Perry device tip:** `9485df8` — **0015** montana sensor_modules (preview);
supersedes live effect of **0014** OTP packaging  
**Kernel tip:** `7c1b60c` — **0004** CCI cci0-only (GPIO_31 / sx9310) — **keep**  
**msm8937-common tip:** `0a23ebb` — patch **0007** (vendor.fm Iris bring-up)  
**Pre-AF bugreport (historical):**  
`~/android/bugreports/perry/bugreport-perry_retail-RQ3A.211001.001-2026-07-20-13-20-02.zip`  
(also `…-dumpstate_log-4221.txt` beside it; **not in git**)  
**TWRP:** on-device + `~/android/twrp` local 3.7.0_9-0 rebuild  
**Build host:** Ubuntu 26.04 LTS; `MKE2FS_CONFIG=$HOME/android/mke2fs.conf`
every build; put `prebuilts/python/linux-x86/2.7.5/bin` first on `PATH`  
**Device:** XT1765 / `ZY224TB8KZ` — booted, USB debugging on  
**pmOS backups:** `~/android/backups/perry/` (Lineage boot, TWRP BD,
sdcard pull, lk2nd getvar dump)  

**Stock firmware (user-provided):**  
`~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml`  
**Unpacked tree:** `~/android/stock-perry-NCQS26.69-64-21/`  
(`mnt-system/`, `mnt-oem/`, `tree/` for extract-files; see [`blobs.md`](blobs.md))

Chronology: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## Next to-dos (2026-07-20 end of session)

Two parallel tracks on the same device. **pmOS is the recently-active track**
(this session); **Lineage/Android is the primary long-term track** (its own
work queue is [§1 below](#1-open-issues--the-work-queue)).

### Done this session (pmOS) — for context

- ✅ **Blocker B cleared** — pmOS boots to a full userspace (`7.0.9-msm89x7`
  aarch64), reachable over USB-net + SSH.
- ✅ **Wi-Fi working** — root-caused the missing perry WCNSS NV; runtime
  installer `scripts/pmos-install-wcnss-nv.sh` + **durable download-based
  pmaport** `firmware-motorola-perry-nv` (PR
  [#2](https://github.com/aneesh-pradhan/xylitol/pull/2)).
- ✅ **Ofilm 499v0 panel first-light** — user-confirmed on the glass.
- ✅ **Committed + pushed** — pmOS docs/overlay/patches on `main`
  (`9ac5652`, `44bbc41`, `9345c36`); public reproduction guide
  [`pmos.md`](pmos.md); firmware pmaport squash-merged via PR
  [#2](https://github.com/aneesh-pradhan/xylitol/pull/2) (`9c4f3a2`).
- ✅ **Feature-matrix walk** — BT/Wi-Fi/display/touch/GPU/accel/battery OK;
  audio needs UCM; cameras/vibrator/prox/ALS/GPS missing or disabled; modem
  AT OK (no SIM). See porting-log 2026-07-20 feature-matrix. **Note:**
  `apk add` rewrote extlinux → `fdtdir` (restored live); durable `fdt` fix
  is now urgent.

### pmOS — next (prioritized)

| # | Task | Notes / where |
|---|---|---|
| 1 | **Merge PR #2** (firmware pmaport) | ✅ Done 2026-07-20 — squash-merged as `9c4f3a2` on `main`. |
| 2 | **Feature-matrix walk** over SSH | ✅ Done 2026-07-20 — results in porting-log. BT/Wi-Fi/display/touch/GPU/accel OK; audio needs perry UCM; cameras (`camss`/`cci` disabled), vibrator, prox/ALS, GPS missing. |
| 3 | **Durable extlinux `fdtdir`→`fdt`** (E-6) | **URGENT** — `apk add` (bluez/…) re-triggered boot-deploy and reset to `fdtdir /` (restored live). Fix options in E-6: perry lk2nd device node (best), override boot-deploy, or post-install hook. |
| 4 | **Fold DTB `fb=okay` into the overlay** (E-6) | Legit (splash/console). Add to overlay 0003 or a new 0007. `usb=peripheral` stays a HACK — real fix is extcon/charger (`pmi8950_smbcharger`, `usb_id` GPIO 97) role detection so `otg` flips on cable. |
| 5 | **Add perry lk2nd device node** | Fixes `fdtdir`, panel auto-select, and the cosmetic "Unknown (FIXME!)". Needs building lk2nd (arm-none-eabi) + reflashing lk2nd to `boot`. Enables #3 the right way. |
| 6 | **Cosmetic: initramfs splash timeout** | `/dev/fb0` appears ~27 s (DPU/DSI bind), past the 10 s initramfs wait → no splash. Bump the wait or get the panel probing earlier. Non-blocking. |
| 7 | **USB-net stability** | Gadget auto-suspends, wiping the host IP. If iterating a lot: pin a NetworkManager profile for the cdc_ncm iface and/or disable device autosuspend. |
| 8 | **(optional) Device-exact NV in the pmaport** | Mirror NV (`3076c1a0…`) ≠ this unit's stock NV (`4f88c4c5…`, in backups). RF/regulatory cal only; MAC is SoC-derived. Bake stock in if you want this exact XT1765's cal — see [`pmos.md`](pmos.md) step 6. |
| 9 | **(optional) Upstream contributions** | Report Ofilm-v0 panel detection to linux-panel-drivers#6 / linux#48; the pmaports NV path mismatch is worth a note too. |

### Lineage/Android — next (unchanged priority)

Full board in [§1](#1-open-issues--the-work-queue). Top items:

| # | Task | State |
|---|---|---|
| 1 | **RIL / mobile network** | **PRIORITY**, untouched. GSM only; never touch `persist`/`modemst*`. |
| 2 | **Camera autofocus** | Open research. Preview/still OK (**0015**); AF `Invalid-region`. Do not re-ship stock `sensor_modules` with montana ISP. Three approaches in §P1a. |
| 3 | Sepolicy pass, hardware audit, release hygiene | §P2/§P3 (fstab `forceencrypt`, drop the `TARGET_KERNEL_VERSION := 4.9` lie, push/fork decision). |

**Cross-cutting rules (both tracks):** SACRED — never wipe/repartition
`persist` / `modemst1` / `modemst2`. No blobs / `out/` / Lineage tree in
xylitol git. No AI co-author trailers on commits or PRs. Never raw-dd a sparse
`vendor.img`.

---

## Phase E pmOS — FLASHED and BOOTING (SESSION 2026-07-20)

**pmOS now boots to a full userspace with Wi-Fi, display, and USB/SSH — see
the [Next to-dos](#next-to-dos-2026-07-20-end-of-session) board for what's
left.** The user opened the Phase-E gate ("fully commit to flashing pmOS").
We flashed lk2nd + the pmOS rootfs and drove the boot failure through several
root causes to a working system: extlinux `fdtdir`→`fdt`, the "blind & mute"
kernel (Blocker B, now cleared), the missing WCNSS Wi-Fi NV, and Ofilm panel
first-light. Everything reversible; **sacred partitions never touched**
(confirmed present in lk2nd's own partition dump). The subsections below are
the chronological bring-up log; the consolidated state + to-dos are up top.

### E-0. Opener for next session (use verbatim)

> Read docs/handoff.md — start with the "Next to-dos" board, then this
> Phase E section. pmOS BOOTS on perry (XT1765): full postmarketOS edge
> userspace (7.0.9-msm89x7 aarch64), Wi-Fi + Ofilm display + USB/SSH all
> working. Reach it over USB-net: self-assign 172.16.42.2/24 on the cdc_ncm
> iface, `ssh aneesh@172.16.42.1` (sudo pw 147147); link auto-suspends so
> re-add IP + timeout-wrap ssh. Blocker B (blind & mute), Wi-Fi (WCNSS NV),
> panel first-light, and the durable NV pmaport (PR #2 merged) are all DONE.
> Feature matrix walked (see porting-log). Next: durable extlinux `fdt` fix
> (URGENT — apk/boot-deploy resets it) and/or perry lk2nd device node. Do not
> touch persist/modemst*.

### E-1. What we did, in order (all succeeded)

1. **Pre-flight verified:** device on adb; r2 kernel apk with Ofilm panel
   (`panel-motorola-perry-499v0-ofilm.ko.zst`) + `msm8917-motorola-perry.dtb`
   installed in rootfs chroot; combined image
   `~/pmos/work/chroot_native/home/pmos/rootfs/qcom-msm89x7.img` (1.28 GiB,
   also symlinked `/tmp/postmarketOS-export/qcom-msm89x7.img`); backups
   present (`~/android/backups/perry/`: `lineage-boot-2026-07-20.img`,
   `twrp-pmos-pre-D-20260720-1656/`, `sdcard-pre-D/` incl. `lineage.zip`).
2. **E1 `pmbootstrap flasher flash_lk2nd`** (from STOCK fastboot) → writes
   lk2nd (314 KB) to the **`boot`** partition. "Image not signed or
   corrupt" is the NORMAL unlocked-Moto warning; it writes anyway (OKAY).
3. **E2 reboot into lk2nd fastboot** (`fastboot reboot`, hold Vol-Down).
   Confirmed lk2nd: `product: lk2nd-msm8952`, `lk2nd:device: perry`,
   `lk2nd:version: 22.0-r2-postmarketos`, empty `version-bootloader`.
   **lk2nd's USB fastboot serial is `24b071b`** (stock aboot serial is
   `ZY224TB8KZ`) — handy tell for which bootloader you're in.
4. **E3 `pmbootstrap flasher flash_rootfs`** (from lk2nd fastboot) → writes
   the combined rootfs disk image to **`userdata`** (sparse, ~95 s). This
   is the destructive step (wiped Lineage userdata; covered by D2 backup).
   "Invalid sparse file format at header magic" is normal fastboot chatter.
5. **E4 boot → FAILED to reach pmOS.** Debugging below.

### E-2. lk2nd behaviour learned (write this on your bones)

- **lk2nd enters fastboot ONLY when Volume-Down is held while booting**
  (per lk2nd README). **USB being plugged does NOT force fastboot.** Vol-Up
  = recovery. No key = normal boot / OS.
- lk2nd shows an on-screen **menu** (reboot / continue / recovery /
  bootloader / EDL / shutdown) when a volume key is held or when it falls
  back after a failed OS boot. "continue" = resume/boot the OS.
- When lk2nd **cannot boot the OS, it FALLS BACK to fastboot mode** and
  shows its menu. So "phone sits in lk2nd on power-on with no key held" ==
  "lk2nd tried to boot and failed."
- **`fastboot oem log && fastboot get_staged <file>`** dumps lk2nd's
  internal ring-buffer log. THIS IS THE #1 DEBUG TOOL. The log persists
  within one lk2nd instance (a reboot / selecting "bootloader" restarts
  lk2nd and clears it — grab the log from the SAME instance that failed).
- lk2nd fastboot USB **enumeration is flaky**: bare `fastboot` blocks
  forever ("< waiting for any device >"). **Always wrap fastboot in
  `timeout N`** and retry a few times.
- `"Unknown (FIXME!)"` on the lk2nd screen + `Failed to find matching
  lk2nd device node: -1` in the log == **lk2nd has NO perry device entry**
  (cosmetic for identity, but see Blocker A — it breaks `fdtdir`).
- To reflash after a hang: force power-off (**hold Power ~10–15 s**), then
  **hold Vol-Down + tap Power** → lk2nd fastboot.

### E-3. Blocker A — lk2nd would not boot the install (FIXED)

**Symptom:** every boot fell back to lk2nd fastboot; USB-net never came up.

**lk2nd log (captured via oem log) — the money quote:**
```
block devices:
 | wrp0p53p1 |          |  826 MiB | Yes |   <- pmOS root (nested in userdata)
 | wrp0p53p0 |          |  487 MiB | Yes |   <- pmOS_boot (nested in userdata)
 | wrp0p53   | userdata | 10269 MiB|     |
...
boot: Trying to boot from the file system...
The dtb-files for this device is not set
Failed to parse extlinux.conf
boot: Bootable file system not found. Reverting to android boot.
ERROR: Invalid boot image header
ERROR: Could not do normal boot. Reverting to fastboot mode.
```
So lk2nd **does** find the nested `pmOS_boot`/root partitions inside
`userdata` (the pmbootstrap "self-contained disk image flashed to
userdata" model works) and reaches filesystem boot — but aborts.

**Root cause (confirmed in lk2nd source `lk2nd/boot/extlinux.c`,
`expand_conf()` ~L370-440):** our generated `extlinux.conf` used
**`fdtdir /`**. For `fdtdir`, lk2nd calls `lk2nd_device_get_dtb_hints()`;
since perry has **no lk2nd device node**, that returns NULL →
`"The dtb-files for this device is not set"` → abort. The `/boot` dir also
contains EVERY generic-port device's DTB (cedric/nora/xiaomi/…/perry), so
"auto-pick" needs the hints perry lacks. lk2nd's parser DOES support an
explicit **`fdt <path>`** / `devicetree` (CMD_FDT, cmd table ~L48-59),
which takes the `else` branch and needs NO device node.

**FIX (Solution 1):** rewrite the boot line to an explicit DTB:
```
    fdt /msm8917-motorola-perry.dtb      # was:  fdtdir /
```
Applied by loop-mounting the flashed image's `pmOS_boot` and editing
`extlinux/extlinux.conf`, then `flash_rootfs` again. **Result: lk2nd now
loads kernel + perry DTB and jumps to it** (fastboot disappears, USB goes
silent → kernel is executing). Blocker A cleared.

### E-4. Blocker B — kernel executes but was SILENT — **CLEARED 2026-07-20**

**RESOLVED.** The kernel boots to a full pmOS userspace and is reachable over
USB-net + SSH (confirmed this session: `ssh aneesh@172.16.42.1`, uptime,
`nmcli`, `dmesg` all live). Whatever combination of the Solution-2 DTB edits /
panel bring-up did it, "blind & mute" is no longer the state — the device
reaches multi-user, NetworkManager, and WiFi. **First on-boot task: bring up
USB-net** — the gadget is CDC-NCM at `172.16.42.1`; the host must self-assign
`172.16.42.2/24` (no DHCP lease is offered) and the link auto-suspends, so
re-add the IP + wrap ssh in `timeout` each reconnect. **WiFi is fixed** (see
below / porting-log). The historical "blind & mute" diagnosis is kept below
for the record.

#### (historical) Blocker B — kernel executes but is SILENT

**Symptom:** after the extlinux fix, `fastboot continue` → lk2nd hands off
(fastboot gone), **no USB-net for 6+ min**, host `dmesg` shows the lk2nd
gadget disconnect then **total USB silence** (no kernel gadget), screen
stuck on lk2nd's last framebuffer. Looks hung.

**Diagnosis — probably NOT a hang; a "blind & mute" kernel.** Read the
perry DTS we ship (`pmos/linux-postmarketos-qcom-msm89x7/0003-*.patch`):
- `chosen { stdout-path = "framebuffer0"; framebuffer0:
  framebuffer@90001000 { compatible="simple-framebuffer"; …
  status = "disabled"; }; }` → **console points at a DISABLED
  framebuffer** and there's no UART cable → kernel has **no console at
  all** → nothing on screen even if it's booting fine.
- `&usb { dr_mode = "otg"; extcon = <&pmi8950_smbcharger>, <&usb_id>; }`
  → gadget only enumerates if extcon role-detection flips to
  **peripheral**; if it doesn't fire (common in early bring-up) →
  **no RNDIS → no `172.16.42.1`**, indistinguishable from a hang.

**Kernel config supports both fixes** (checked `/boot/config` in rootfs):
`CONFIG_DRM_SIMPLEDRM=y`, `CONFIG_FB=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`
(so enabling the fb node gives an on-screen console + simpledrm→DRM
handover), `CONFIG_USB_GADGET=y`, `CONFIG_USB_CONFIGFS=m` (RNDIS/NCM/ECM
present; configfs is an initramfs-loaded module).

**Solution 2 (PREPARED, host-side, DTB-only — verify if reflashed):**
Edited the perry DTB in the flashed image (no kernel rebuild):
- `framebuffer@90001000` `status "disabled"` → **`"okay"`** (on-screen
  console; even before the Ofilm DRM driver loads).
- `&usb` `dr_mode "otg"` → **`"peripheral"`** (force gadget → USB-net/SSH).
Method: `sudo apt-get install device-tree-compiler` (host now has dtc
1.7.2); loop-mount image `pmOS_boot`; `dtc -I dtb -O dts` the
`/msm8917-motorola-perry.dtb`; edit those two lines; `dtc -I dts -O dtb`;
write back to BOTH `/msm8917-motorola-perry.dtb` and
`/dtbs/qcom/msm8917-motorola-perry.dtb` (DTB grew 50523→50527 B); unmount.
**Image is patched; the reflash + boot was NOT yet done when this handoff
was written** (phone was being recovered to lk2nd fastboot). Next session:
confirm state, `flash_rootfs`, `fastboot continue`, watch screen + USB.

**Expected outcomes of Solution 2 boot:**
- Panel shows scrolling kernel/boot text → kernel is alive; read where it
  goes / hangs. And/or USB-net at `172.16.42.1` → `ssh aneesh@172.16.42.1`
  (key baked in), then `dmesg` tells us everything (incl. Ofilm panel).
- If framebuffer shows boot then freezes at a point → that's the REAL
  early hang; debug that DTS node (compare vs booting sibling nora/montana,
  same kernel).

### E-5. Reflash / boot recipe (fast iteration, no kernel rebuild)

```bash
export PATH="$HOME/bin:$PATH"
IMG=/home/aneesh/pmos/work/chroot_native/home/pmos/rootfs/qcom-msm89x7.img
# --- edit files inside pmOS_boot (partition 1, ext2, 487 MiB) ---
LOOP=$(sudo losetup -fP --show "$IMG")     # ${LOOP}p1=pmOS_boot ${LOOP}p2=root
sudo mount "${LOOP}p1" /mnt/x              # extlinux/extlinux.conf, *.dtb, dtbs/
# ...edit...
sync; sudo umount /mnt/x; sudo losetup -d "$LOOP"
# --- phone must be in lk2nd fastboot (hold Vol-Down + Power) ---
timeout 8 fastboot getvar product          # expect: lk2nd-msm8952
pmbootstrap flasher flash_rootfs           # sends THIS image (sparses live), ~95 s
timeout 10 fastboot continue               # lk2nd boots the kernel
# watch: ip -brief addr | grep -iE 'usb|enx'; ping 172.16.42.1; ssh aneesh@172.16.42.1
```
Notes: `flash_rootfs` does NOT regenerate — it flashes the current raw
`qcom-msm89x7.img`, so loop-mount edits survive. `pmbootstrap install`
DOES regenerate (would overwrite extlinux via boot-deploy → back to
`fdtdir`). So for iteration, edit-image + flash_rootfs; don't re-run
install unless you also re-apply the extlinux/DTB fixes.

### E-6. DURABLE fixes still owed (we've been using throwaway image hacks)

Both Solution 1 (extlinux `fdt`) and Solution 2 (DTB fb/usb) are edits to
the *flashed image*, lost on any `pmbootstrap install`. To make them
reproducible in the xylitol overlay:
- **extlinux `fdtdir`→`fdt`:** `boot-deploy`'s `create_extlinux_config`
  emits `fdtdir /`. Options: (a) the RIGHT fix — **add a perry device node
  to lk2nd** so `lk2nd_device_get_dtb_hints()` works (also fixes panel
  selection & "Unknown (FIXME!)"); needs building lk2nd (arm-none-eabi) +
  reflashing lk2nd to `boot`. (b) patch/override boot-deploy or set a
  single `deviceinfo_dtb` so it emits explicit `fdt`. (c) a post-install
  hook that rewrites extlinux.conf.
- **DTB fb=okay:** legit to fold into overlay patch 0003 (or new 0007) —
  a simple-framebuffer splash/console is normal & upstreamable.
- **DTB usb=peripheral:** a bring-up HACK. Upstream-correct fix = make
  extcon/charger (`pmi8950_smbcharger`, `usb_id` GPIO 97) role detection
  work so `otg` flips to peripheral on cable insert. Keep `peripheral`
  only until USB role detection is sorted.

### E-7. Wiki / source findings (via in-app Browser; wiki blocks WebFetch/Anubis)

- **Perry is ARCHIVED** in pmOS ("no longer in pmbootstrap… likely broken…
  build the kernel package manually") — matches our manual r2 carry.
- Perry wiki **feature matrix claims Works**: Flashing, USB-net, Battery,
  **Screen**, Touch, 3D, Audio, WiFi, BT, OTG, accel (Camera broken; modem
  partial). So a mainline kernel HAS driven this hardware — Solution 2
  should get us there.
- Generic **qcom-msm89x7** port lists sibling MSM8917/8937 Motos
  (cedric/montana/hannah/nora) as supported on the SAME kernel+lk2nd — use
  **nora** (also MSM8917) or montana as the "known-good DTS" to diff perry
  against if Blocker B turns out to be a real hang.
- Documented install = `flash_lk2nd` → confirm lk2nd → `flash_rootfs` →
  reset. **lk2nd REQUIRED** (selects panel; without it black screen).
  **No `flash_kernel` needed** (lk2nd boots kernel from the pmOS_boot ext2
  via extlinux). OS image lives at 512 KiB offset in `boot` OR an ext2 fs
  (we use the ext2/extlinux path — supported).

### E-8. Rollback to Lineage (any time, from STOCK fastboot)

`fastboot flash boot ~/android/backups/perry/lineage-boot-2026-07-20.img`
(removes lk2nd) → `fastboot boot ~/android/recovery/twrp-3.7.0_9-0-perry.img`
→ TWRP restore `data` from `twrp-pmos-pre-D-20260720-1656/` (or wipe data
for a clean first boot). `system`/`oem` were never touched by pmOS.
Sacred `persist`/`modemst1`/`modemst2`/`fsg` never in play.

### E-9. Scratchpad artifacts (SESSION-LOCAL — will NOT persist)

lk2nd log dumps and the DTB work-tree lived in the session scratchpad and
are gone next session — but the essential log content and the exact recipe
are captured above, so nothing important is lost. The **patched image on
disk** (`qcom-msm89x7.img`) DOES persist and carries the extlinux `fdt`
fix (+ the DTB fb/usb edits if the write completed — verify by
loop-mounting and checking `extlinux.conf` + `dtc -I dtb` on the perry
DTB's `framebuffer@90001000`/`dr_mode`).

### E-10. USB access + WiFi — WORKING (2026-07-20)

**USB-net / SSH (do this first each session):**
```bash
# find the gadget iface (cdc_ncm, PRODUCT=18d1/d001; lsusb mislabels "Nexus 4")
IFACE=$(for n in /sys/class/net/*; do grep -q cdc_ncm "$n/device/uevent" 2>/dev/null && basename "$n"; done)
sudo ip addr add 172.16.42.2/24 dev "$IFACE"; sudo ip link set "$IFACE" up
ping 172.16.42.1                          # device
ssh aneesh@172.16.42.1                     # key auth; sudo pw 147147
```
The link **auto-suspends / re-enumerates** (wipes the host IP) — re-add
`172.16.42.2/24` and `timeout`-wrap every ssh before each reconnect.

**WiFi (fixed):** root cause was our DTS pointing `wcn36xx` at
`qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin`, which the rootfs did not
ship → `-2` → no `wlan0`. Installed perry's own NV (`4f88c4c5…`, 31723 B, from
the Lineage build's `vendor/etc/wifi/`) at that path:
```bash
./scripts/pmos-install-wcnss-nv.sh      # idempotent; blob NOT in git (*.bin)
```
Then **reboot** (never manual `remoteproc` restart — it wedges WCNSS SMD):
`sudo sh -c 'sync; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger'`.
Cold boot → `wlan0` up, associates + DHCP, NM auto-reconnects. **Durable fix
DONE:** pmaport `pmos/firmware-motorola-perry-nv/` +
`scripts/pmos-apply-perry-firmware.sh` bakes the NV into the rootfs
(`pmbootstrap build firmware-motorola-perry-nv` →
`install --add firmware-motorola-perry-nv`), surviving `pmbootstrap install`.
Named `-nv` to avoid the archived `firmware-motorola-perry` (wrong
`/lib/firmware/postmarketos/…` path). The APKBUILD **downloads** the blob from
the community mirror pmaports pins (user OK'd outside sources; no blob in git,
no extraction). Mirror NV `3076c1a0…` differs from this unit's stock NV
`4f88c4c5…` (RF/regulatory cal only; MAC is SoC-derived) — device-exact via the
runtime `pmos-install-wcnss-nv.sh` or an aport `source=` override. Build-
validated. See PR [#2](https://github.com/aneesh-pradhan/xylitol/pull/2).
Notes: NV blob stable copy at `~/android/backups/perry/WCNSS_qcom_wlan_nv.perry.bin`;
wcn36xx MAC is device-derived (`02:00:02:4b:07:1b`), not from the NV.

---

## How to start the next session

**Android opener (use this verbatim):**

> Read docs/handoff.md end-to-end and continue perry bring-up. Priority:
> **RIL / mobile network** (or camera AF if continuing — see P1a tradeoff).
> Preview works again after 0015; AF still `Invalid-region`. FM done (0007).
> Stock dump at
> ~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml
> (unpacked under ~/android/stock-perry-NCQS26.69-64-21/). Staging-4.9
> is parked — do not start it unprompted.

**pmOS Ofilm panel research opener (use this verbatim):**

> Read docs/pmos-ofilm-panel.md end-to-end and research the XT1765 Ofilm
> 499 panel gap for postmarketOS. Phases B–D are done; do not flash Phase E
> or edit the kernel overlay unless asked. Deliver the write-up listed in
> §6 of that brief. Downstream MDSS source is in the Lineage msm8953 tree
> (`dsi-panel-mot-ofilm-499-720p-video*.dtsi`). lk2nd getvar dump:
> ~/android/backups/perry/lk2nd-getvar-all.txt.

**Agent checklist (Android):**

1. Read this file + porting-log 2026-07-20 camera AF / 0015 regression.
2. Sanity: `qcamerasvr=running`, `dumpsys media.camera` → 2 devices;
   Snap preview + still OK; expect `Invalid-region` again (AF open).
3. Next P1: **RIL** (§1 #3), unless user wants another AF approach.
4. No AI co-author trailers. Sacred: no persist/modemst wipes. Never
   raw-dd sparse `vendor.img`.

**Agent checklist (pmOS panel research):**

1. Read [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) only (self-contained).
2. Answer §3 questions; write §6 deliverable. No flash, no overlay edits.

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
**0014** + kernel **0004** got OTP AF cal working (DAC ranges logged,
`Invalid-region` gone) but stock `sensor_modules` with montana ISP caused
`isp_util_map_streams` **sensor resolution 0x0** → black viewfinder /
"Camera isn't responding". **0015** reverts packaging to montana
`sensor_modules` + omit EepromName; preview restored; AF broken again.
Kernel **0004** (CCI cci0-only) stays — GPIO_31 clash was real.

**Working assumption:** check staging-4.9-isms first; for camera, packaging
before shims. **Do not re-ship stock sensor_modules with montana ISP.**

---

## 1. Open issues — the work queue

### P1 — next session

| # | Issue | State / next step |
|---|---|---|
| 1 | Soft navbar | **FIXED.** |
| 2 | **Camera autofocus** | **OPEN research** — not fixed. Preview/still OK (**0015**). OTP packaging (**0014**) got AF cal working then broke preview (`sensor resolution: 0x0`). Do not re-ship stock `sensor_modules` with montana ISP. Next AF: full stock camera stack, montana `eeprom_process` fix/shim, or actuator `.bin` from OTP DAC ranges. |
| 3 | **Mobile network / RIL** | **PRIORITY** unless continuing AF. Untouched. Stock NCQS26.69-64-21. GSM only; never touch `persist`/`modemst*`. |

### P1a — Camera (post-0015)

**Done**
- **0011:** montana platform stack; qcamerasvr stable.
- **0012:** XT1765 sensors/chromatix/actuator; vendor
  `msm8937_mot_camera_conf.xml`; EepromName omitted (SEGV workaround).
- **0013:** install `libactuator_dw9718s.so` also as
  `libactuator_dw9718s_truly.so` (`device.mk` PRODUCT_COPY_FILES).
- **Kernel 0004:** CCI cci0-only — keep (clears GPIO_31 / sx9310).
- **0014 (historical):** EepromName + stock sensor_modules → OTP AF cal
  worked; **broke preview**.
- **0015:** back to montana sensor_modules; EepromName omitted.

**Live verified (2026-07-20 after 0015 vendor flash)**
- Montana `sensor_modules` MD5 `b57cabd8…` on `/vendor`.
- `dumpsys media.camera`: **2 devices**; Snap `PROFILE_OPEN … rc: 0`.
- Preview path: 960×720; stills `IMG_20260720_1432*.jpg` (~2.5 MB).
- No `resolution: 0x0` / no Snap ANR.
- AF: `Invalid-region size = 0` back (expected).

**OTP DAC ranges captured while 0014 was live (reuse for actuator.bin try)**
- infinity −55..280, macro +61..589, initial code 280
  (`s5k4h8_eeprom_autofocus_calibration`).

**Next AF approaches (do not mix stock sensor_modules + montana ISP)**
1. Full XT1765 stock camera stack (ISP/iface/sensor_modules together).
2. Fix/shim montana `eeprom_process` SEGV with EepromName + montana modules.
3. Ship actuator ringing / region params from known DAC ranges without OTP.

**Packaging**

| Makefile | Role |
|---|---|
| `camera-vendor.mk` | Montana platform including sensor_modules / eeprom_util / pdaf / motocalibration (**0015**) |
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
dw9718s_truly alias · **0014** OTP attempt (stock sensor_modules) ·
**0015** keep montana sensor_modules (preview)  
**msm8937-common (18.1):** 0001–0006 · **0007** vendor.fm Iris / FM2  
**kernel msm8953 (18.1):** 0001–0003 · **0004** CCI cci0-only  
Meta: `config/mke2fs.conf`

0015 at perry `9485df8`; 0004 at kernel `7c1b60c`; 0007 at msm8937-common `0a23ebb`.

**Key paths:**

| Item | Path |
|---|---|
| Handoff | `docs/handoff.md` |
| Camera 0011 | `patches/device/motorola/perry/0011-perry-ship-msm8937-camera-platform-stack-from-montana.patch` |
| Camera 0012 | `patches/device/motorola/perry/0012-perry-ship-XT1765-camera-sensors-and-vendor-camera-conf.patch` |
| Camera 0013 | `patches/device/motorola/perry/0013-perry-alias-dw9718s-actuator-as-dw9718s_truly-for-open.patch` |
| Camera 0014 | `patches/device/motorola/perry/0014-perry-restore-EepromName-OTP-with-stock-sensor-modules.patch` |
| Camera 0015 | `patches/device/motorola/perry/0015-perry-keep-montana-sensor_modules-stock-breaks-preview.patch` |
| Kernel 0004 | `patches/kernel/motorola/msm8953/0004-perry-CCI-pinctrl-cci0-only-avoid-GPIO_31-sx9310-clash.patch` |
| FM 0007 | `patches/device/motorola/msm8937-common/0007-msm8937-common-add-vendor.fm-Iris-bring-up-for-FM2.patch` |
| Perry device tree | `~/android/lineage/device/motorola/perry/` |
| Stock unpack | `~/android/stock-perry-NCQS26.69-64-21/` |
| Extract wrapper | `~/GitHub/xylitol/scripts/extract-perry.sh` |
| pmOS WCNSS NV installer | `scripts/pmos-install-wcnss-nv.sh` (blob not in git) |

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
adb logcat -d | grep -iE 'actuator|EEPROM|initializeImpl|CAM_Photo|PROFILE_OPEN|resolution: 0x0'
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

**Android next: RIL** (or AF without stock+montana mix). Preview restored
(0015); AF still `Invalid-region`. FM done (0007).

**pmOS next: BOOTS + WiFi up (Blocker B cleared).** Reachable via
`ssh aneesh@172.16.42.1` (see E-10 for USB-net setup). Next: confirm panel
first-light on screen, walk the feature matrix (BT/audio/sensors/GPS/vibra),
make the WCNSS NV durable as a local pmaport. Ofilm driver 0005/0006,
7.0.9-r2; findings [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) §7. Never
raw-dd sparse vendor. Sacred: no persist/modemst wipes.

---

## 6. Side quests (do not start unprompted)

- **postmarketOS / mainline:** **ACTIVE — BOOTS.** Phases B–E done. pmOS
  edge (`7.0.9-msm89x7` aarch64) boots to userspace; USB-net + SSH; **WiFi
  working** (`scripts/pmos-install-wcnss-nv.sh`; see E-10 + porting-log
  2026-07-20). Artifacts: `/tmp/postmarketOS-export/`, backups
  `~/android/backups/perry/` (incl. `WCNSS_qcom_wlan_nv.perry.bin`). Lineage
  intact (rollback E-8). **Ofilm 499v0 panel first-light CONFIRMED**
  (user-witnessed; driver 0005/0006, `compatible: motorola,perry-499v0-ofilm`).
  **Open:** remaining feature matrix (BT/audio/sensors/GPS); durable NV
  pmaport; cosmetic initramfs-splash timeout. Brief:
  [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md). Plan/runbook:
  [`pmos-perry.md`](pmos-perry.md), [`pmos-runbook.md`](pmos-runbook.md).
  PR [#48](https://github.com/msm89x7-mainline/linux/pull/48)
  DTS remains the best hardware map for Android HAL/sepolicy too.
- **staging-4.9 kernel port:** [`kernel-4.9-plan.md`](kernel-4.9-plan.md).
  Gate: 18.1 camera AF + RIL done first.
