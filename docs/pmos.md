# postmarketOS (mainline) on Moto E4 perry — status & reproduction

A second, independent track for the XT1765 `perry`: a **mainline Linux**
postmarketOS install, separate from the LineageOS 18.1 port that is this
repo's primary focus. This is a Linux-on-phone experiment — not a
daily-driver Android replacement — but the base is real and usable.

> **Nothing here integrates with the LineageOS port.** Mainline replaces the
> Nougat vendor stack (ION/mdss/KGSL/prima) with upstream DRM/msm, freedreno,
> and wcn36xx. The two tracks share only the hardware and the backups.

## What works (verified 2026-07-20, this device)

| Area | State |
|---|---|
| Boot to userspace | ✅ postmarketOS edge, kernel `7.0.9-msm89x7`, **aarch64** |
| Display (Ofilm 499v0 panel) | ✅ **first-light confirmed** — msm DPU → DSI → `motorola,perry-499v0-ofilm`, 720×1280, backlight under driver control |
| USB networking + SSH | ✅ CDC-NCM gadget at `172.16.42.1`, key-based SSH |
| Wi-Fi (`wcn36xx`) | ✅ scans + associates (WPA2) + DHCP + internet, auto-reconnects on boot |
| Console | ✅ framebuffer console + `agetty` login on the panel |
| Sacred partitions | untouched — `persist` / `modemst1` / `modemst2` never flashed |

Not yet exercised here: Bluetooth, audio, sensors, GPS, vibrator, cameras.
The pmOS wiki feature matrix claims most of these work on this
kernel+lk2nd; treat them as "probably, untested by us."

Two known rough edges:
- **No boot splash.** The initramfs splash times out
  (`/dev/fb0 did not appear after waiting 10 seconds`) because the DRM
  framebuffer only appears at ~27 s when the DPU/DSI binds. The console
  framebuffer comes up fine right after — cosmetic only.
- **Wi-Fi NV must be added by hand** (see step 6) and is a proprietary blob,
  so it is not shipped in this repo.

## Heads-up before you start

- **This is destructive to `userdata`.** The pmOS rootfs is flashed to the
  `userdata` partition — it wipes your Android user data. `system`/`oem`
  (Lineage) are left intact, so you can roll back (see below), but back up
  anything on internal storage first.
- **SACRED partitions:** never wipe, flash, or repartition `persist`,
  `modemst1`, `modemst2` (EFS/IMEI/calibration). The `pmbootstrap flasher`
  commands below touch only `boot` (lk2nd) and `userdata` (rootfs). If any
  tool offers to touch the sacred three, stop.
- **perry is archived in pmOS** — it was dropped from `pmbootstrap`'s device
  list, so the packaged kernel has **no perry DTB**. This repo's `pmos/`
  overlay carries the DTS + panel drivers to fill that gap (step 3).
- Our unit is **XT1765 / MSM8917** (the wiki often says MSM8920 / XT1766).
- Bootloader must be **unlocked**.

## Prerequisites

- A Linux build host (we use Ubuntu; macOS won't work).
- [`pmbootstrap`](https://wiki.postmarketos.org/wiki/Pmbootstrap) 3.11+ on
  `PATH`.
- `fastboot`, `ssh`, `device-tree-compiler` (`dtc`), and root (`sudo`) on the
  host.
- **Backups you make yourself, off-device** (do this in TWRP or equivalent
  *before* flashing):
  - Your current `boot` partition (to roll back to Android).
  - A full data/system backup if you want to return to your exact setup.
  - Confirm you already have safe copies of `persist` / `modemst1` /
    `modemst2` — these hold your IMEI/EFS and must never be lost.

## Reproduce it

Paths below assume this repo is at `~/GitHub/xylitol` and a pmbootstrap
workdir at `~/pmos`. Adjust to taste.

### 1. Initialise pmbootstrap for the generic MSM8917/8937 port

```bash
pmbootstrap init
#   vendor:  qcom
#   device:  qcom-msm89x7      (generic MSM8917/8937 Qualcomm port)
#   kernel:  postmarketos-qcom-msm89x7
#   UI:      console  (or a GUI if you want to try one)
#   set a username; enable SSH keys:
pmbootstrap config ssh_keys True
```

### 2. (optional) Understand the overlay

The packaged `linux-postmarketos-qcom-msm89x7` kernel has no perry support.
The overlay in [`../pmos/`](../pmos/) carries, as `.patch` files applied on
top of the pmaports kernel package:

| Patch | What |
|---|---|
| 0001–0003 | perry DTS + MSM8920 support + rmi_i2c reset GPIO — from [msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48) |
| 0004 | Tianma 499v1 panel driver (other perry units) |
| 0005 | **Ofilm 499v0 panel driver** (our unit) |
| 0006 | DTS: select the Ofilm 499v0 panel |

Perry's 499 panel was quad-sourced (Tianma / BOE / INX / Ofilm). Check which
you have — lk2nd reports it, e.g.
`lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0` → Ofilm v0. If yours
is Tianma, 0006 should select `motorola,perry-499v1-tianma` instead.

### 3. Apply the overlay and build the kernel

```bash
cd ~/GitHub/xylitol
./scripts/pmos-apply-perry-kernel.sh          # copies patches + APKBUILD into live pmaports
pmbootstrap checksum linux-postmarketos-qcom-msm89x7
pmbootstrap build   linux-postmarketos-qcom-msm89x7
# sanity: the apk must contain boot/dtbs/qcom/msm8917-motorola-perry.dtb
```

### 4. Build the install image and flash lk2nd

```bash
pmbootstrap install          # builds the combined boot+root rootfs image
pmbootstrap export           # symlinks lk2nd.img + qcom-msm89x7.img into /tmp/postmarketOS-export/

# from STOCK fastboot (adb reboot bootloader):
pmbootstrap flasher flash_lk2nd
#   writes lk2nd (~314 KB) to the `boot` partition.
#   "Image not signed or corrupt" is the NORMAL unlocked-Moto warning — it writes anyway.
```

Reboot into **lk2nd fastboot**: `fastboot reboot`, then hold **Volume-Down**
while it boots. Confirm you're in lk2nd:
`fastboot getvar product` → `lk2nd-msm8952`; `lk2nd:device: perry`.

### 5. Fix the extlinux boot entry, then flash the rootfs

lk2nd has no perry device node, so the auto-generated `extlinux.conf` uses
`fdtdir /` — which lk2nd cannot resolve for perry and the boot aborts. Rewrite
it to an **explicit DTB** before flashing. Loop-mount the boot partition of
the export image and edit one line:

```bash
IMG=~/pmos/work/chroot_native/home/pmos/rootfs/qcom-msm89x7.img
LOOP=$(sudo losetup -fP --show "$IMG")        # ${LOOP}p1 = pmOS_boot
sudo mount "${LOOP}p1" /mnt/x
sudoedit /mnt/x/extlinux/extlinux.conf        # change:  fdtdir /   ->   fdt /msm8917-motorola-perry.dtb
sync; sudo umount /mnt/x; sudo losetup -d "$LOOP"
```

Then, from **lk2nd fastboot**:

```bash
pmbootstrap flasher flash_rootfs             # writes the combined image to `userdata` (~95 s, destructive)
```

### 6. Add the Wi-Fi calibration blob (proprietary — you supply it)

perry's DTS points `wcn36xx` at
`qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin`, which the stock rootfs
does not ship. Without it the driver fails with `-2` (ENOENT) and no `wlan0`
appears. Provide perry's own `WCNSS_qcom_wlan_nv.bin` (extract it from your
device's vendor partition or a stock firmware image — it is **not** in this
repo).

Once the device has booted far enough for USB-net + SSH (step 7), install it:

```bash
# host static IP on the CDC-NCM gadget interface (no DHCP lease is offered):
IFACE=$(for n in /sys/class/net/*; do grep -q cdc_ncm "$n/device/uevent" 2>/dev/null && basename "$n"; done)
sudo ip addr add 172.16.42.2/24 dev "$IFACE"; sudo ip link set "$IFACE" up

WCNSS_NV_SRC=/path/to/your/perry/WCNSS_qcom_wlan_nv.bin \
  ./scripts/pmos-install-wcnss-nv.sh
```

The script copies the blob to the right path, verifies its checksum, and
prints the reboot command. **Reboot** to activate it — a clean cold boot
loads the NV and `wcn36xx` creates `wlan0`. Do **not** restart the WCNSS
`remoteproc` by hand to pick up the NV; that wedges the WCNSS SMD channel and
you'll have to reboot anyway.

> Caveat: this writes to the rootfs and survives reboots, but a future
> `pmbootstrap install` regenerates the rootfs and wipes it. For a durable
> setup, package the blob as a local pmaport (`firmware-motorola-perry`) in
> your device package's `depends`. Kept out of this repo because the blob is
> proprietary.

### 7. Boot, connect, verify

```bash
fastboot continue            # lk2nd boots the kernel

# host: bring up USB-net (the link auto-suspends; re-add the IP + wrap ssh in `timeout` on reconnects)
IFACE=$(for n in /sys/class/net/*; do grep -q cdc_ncm "$n/device/uevent" 2>/dev/null && basename "$n"; done)
sudo ip addr add 172.16.42.2/24 dev "$IFACE"; sudo ip link set "$IFACE" up
ping 172.16.42.1
ssh <your-user>@172.16.42.1

# on the device, once Wi-Fi NV is installed + rebooted:
nmcli dev wifi list
nmcli dev wifi connect '<SSID>' password '<PSK>'
```

## Roll back to LineageOS / Android

Everything above is reversible; `system`/`oem` are never touched.

1. From **stock fastboot**, restore your saved boot image:
   `fastboot flash boot <your-lineage-or-stock-boot>.img` (this removes lk2nd).
2. Boot TWRP (`fastboot boot twrp.img`) and restore `data` from your
   pre-pmOS backup, or wipe data for a clean first boot.
3. The sacred `persist` / `modemst1` / `modemst2` were never in play.

## Deeper notes

- Chronology + root-cause write-ups: [`porting-log.md`](porting-log.md)
  (see the 2026-07-20 "pmOS BOOTS to userspace" entry).
- Maintainer session state / exact recipes: [`handoff.md`](handoff.md)
  (§ Phase E pmOS, incl. E-10 USB/Wi-Fi).
- Overlay details: [`../pmos/README.md`](../pmos/README.md).
- Panel research: [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md).
- Original plan / phased runbook: [`pmos-perry.md`](pmos-perry.md),
  [`pmos-runbook.md`](pmos-runbook.md).
- Upstream perry hardware map: [msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48).
