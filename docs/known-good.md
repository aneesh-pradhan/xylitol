# Known-good pins (perry / xylitol)

Record of patch tips that matched a booting LineageOS 18.1 build on XT1765.
Re-verify after `repo sync` — upstream moto-msm89xx tips move.

**Snapshot date:** 2026-07-20

## Meta-repo patch series

| Tree | Patches | Live tip (after `git am`) |
|---|---|---|
| `device/motorola/perry` (17.1 base) | `0001`–`0013` | `8c6bae3` — dw9718s_truly alias |
| `device/motorola/msm8937-common` (18.1) | `0001`–`0007` | `0a23ebb` — vendor.fm Iris |
| `kernel/motorola/msm8953` (18.1) | `0001`–`0003` | `525e6770eb8c` — pronto WLAN inline |
| TWRP `device/motorola/perry` | `0001` | shrink recovery to fit partition |

Full SHAs (2026-07-20 trees):

```
device/motorola/perry:            8c6bae34161c9a4b2c7473f4c05ec17a7f2ae3d8
device/motorola/msm8937-common:   0a23ebbb905d0ca3a99662eecbd6840ed1551036
kernel/motorola/msm8953:          525e6770eb8cfe7ee5c6ca72c1c6ae2a4bf2f45c
```

Upstream bases before patches (local manifest revisions):

| Project | Remote branch |
|---|---|
| `android_device_motorola_perry` | `moto-msm89xx` `lineage-17.1` |
| `android_device_motorola_msm8937-common` | `moto-msm89xx` `lineage-18.1` |
| `android_kernel_motorola_msm8953` | `moto-msm89xx` `lineage-18.1` |
| `proprietary_vendor_motorola` | `moto-msm89xx` `lineage-18.1` |
| LineageOS platform | `LineageOS/android` `lineage-18.1` |

## Verified on device (that tip)

- Boots to UI; touch; adb; Wi-Fi; soft navbar; SELinux Enforcing
- FM radio (enable/tune + RDS)
- Camera: open + still (front and back); AF / EEPROM still broken

## Rebuild checklist

```bash
./scripts/sync.sh
./scripts/apply-patches.sh
# confirm tips:
git -C ~/android/lineage/device/motorola/perry rev-parse --short HEAD
git -C ~/android/lineage/device/motorola/msm8937-common rev-parse --short HEAD
git -C ~/android/lineage/kernel/motorola/msm8953 rev-parse --short HEAD
./scripts/extract-perry.sh adb   # or stock tree
./scripts/build.sh
```

If `git am` fails after a fresh sync, upstream moved — stop and rebase/export a
new patch series rather than forcing am.
