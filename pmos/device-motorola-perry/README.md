# device-motorola-perry — first-class pmOS device package

Codename `motorola-perry` for `pmbootstrap`. Depends on
`linux-motorola-perry` (custom kernel) plus perry NV / UCM / lk2nd.

See [`../../docs/perry-custom-kernel-plan.md`](../../docs/perry-custom-kernel-plan.md).

## Ships

| File | Role |
|---|---|
| `deviceinfo` | Single DTB `qcom/msm8917-motorola-perry`, zram 100%/zstd |
| `modules-initfs` | Initramfs modules (touch + Ofilm panel + msm DRM) |
| `50-perry-wlr.conf` | `WLR_DRM_NO_ATOMIC=1` (P0.3) |
| `50-perry-usb-nosuspend.rules` | USB gadget stay-awake (P0.5) |
| `60-perry-emmc-scheduler.rules` | `mq-deadline` on `mmcblk0` (P1.4) |
| `80-device-motorola-perry.preset` | Mask cups/flatpak/fprintd/tuned if present (P0.4) |
| linger `xylitol` | PipeWire without open login |

## Apply / build (no flash)

```bash
./scripts/pmos-apply-device-perry.sh
pmbootstrap checksum device-motorola-perry
pmbootstrap build    device-motorola-perry
```

Removes local `device/archived/device-motorola-perry` on apply (pkgname clash
with upstream’s archived 3.18 aport).

Published Phosh release path still uses `qcom-msm89x7` + overlays until an
explicit cutover.

**Boot status (2026-07-22):** Phase B images using this package **hang** on
hardware (black screen + backlight, no USB). Bisect A kept ofilm out of
early `modules-initfs` (pkgrel 4) — not sufficient alone. See
[`docs/phase-b-boot-hang-bisect.md`](../../docs/phase-b-boot-hang-bisect.md).
Daily-driver flash: release `pmos-perry-2026-07-21` only.
