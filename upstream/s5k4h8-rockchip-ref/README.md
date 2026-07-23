# Reference: Rockchip S5K4H8 V4L2 driver

**Source tree:** scpcom/linux @ `94c738a0b0830b0749ef66eb9e7ba6e514f183df`  
**URL:** https://git.servator.de/scpcom/linux/-/blob/94c738a0b0830b0749ef66eb9e7ba6e514f183df/drivers/media/i2c/s5k4h8.c  
**Fetched:** 2026-07-22 (perry rear camera bring-up)

## License / copyright

- SPDX: GPL-2.0
- Copyright (C) 2017 Fuzhou Rockchip Electronics Co., Ltd.
- Comment in source: "V0.0X01.0X0 first version,otp is not verified"

## Why we keep this

Register tables and stream-on semantics from this driver match XT1765 stock
`libmmcamera_s5k4h8.so` closely and produced **rear first light** on
postmarketOS mainline CAMSS (linux-motorola-perry 7.1.3-r8).

Perry port is **not** a straight copy: Rockchip-only pieces
(`rk-camera-module.h`, pinctrl state names, RKMODULE ioctls, OTP/AWB vendor
path) were dropped; I/O uses mainline `v4l2-cci`; pad ops follow the in-tree
`ov5695` pattern used on the same SoC.

## Key facts taken from this file

| Item | Value |
|------|--------|
| CHIP_ID | 0x4088 @ reg 0x0000/0x0001 |
| Lanes | 4 |
| XVCLK | 24 MHz |
| Link freq | 280 MHz (560 Mbps/lane) |
| Pixel rate | 224000000 |
| Modes | 3264×2448 (~25 fps), 1632×1224 binning (~30 fps) |
| Stream on | **8-bit** write 0x01 to 0x0100 (not 0x0100 as 16-bit) |
| Stream off | 8-bit 0x00 to 0x0100 |
| Exposure | 0x0202 (16-bit) |
| Analogue gain | 0x0204 (16-bit), min 32 max 1024 |
| VTS | 0x0340 |
| Global init | `s5k4h8_global_regs[]` (TNP via 0x6F12 + FCFC page) |

## Local carry (perry / xylitol)

| Item | Path |
|------|------|
| Kernel patch | `pmos/linux-motorola-perry/patches/0009-media-i2c-add-Samsung-S5K4H8-sensor-probe-chip-id.patch` |
| DT | `pmos/linux-motorola-perry/patches/0010-arm64-dts-qcom-perry-enable-rear-s5k4h8-camera.patch` |
| Docs (verbose) | `docs/pmos-camera-perry.md` |
| Porting log | `docs/porting-log.md` |
| First-light still | `artifacts/camera-rear-first-light-2026-07-22/` (gitignored) |
| Duplicate fetch | `artifacts/refs/s5k4h8-rockchip-94c738a0/` (gitignored) |

**Proven on-device (XT1765, 2026-07-22):** libcamera lists both cameras;
rear captures 3264×2448 GRBG10 @ ~24 fps on `linux-motorola-perry` **7.1.3-r8**.

## Files in this directory

- `s5k4h8.c` — full upstream Rockchip driver snapshot (do not build as-is on mainline)
- Other files if fetch succeeded (Kconfig fragment, rk-camera-module.h, …)
