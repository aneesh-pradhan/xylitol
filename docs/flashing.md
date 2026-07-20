# Flashing and recovery (perry)

## Sacred partitions

Back up off-device before experimenting. **Never** wipe, format, or repartition:

| Partition | Why |
|---|---|
| `persist` | Calibration / radio persistence |
| `modemst1` | EFS / IMEI |
| `modemst2` | EFS / IMEI |

If a script or guide could touch these, stop.

## TWRP

- Prefer **`fastboot boot twrp.img`** over flashing recovery until the ROM is
  stable.
- Official-tree rebuild: `scripts/sync-twrp.sh` → `apply-twrp-patches.sh` →
  `build-twrp.sh` (see also GitHub Actions workflow `twrp.yml`).
- Recovery image from a CI release (when published): boot it the same way.

Unlocked bootloader is required (`fastboot getvar unlocked` → `yes`).

## First install (high level)

1. Boot TWRP (`fastboot boot twrp.img`).
2. Wipe **only** what you intend (typically dalvik/cache + data for a clean
   first flash). Do **not** wipe the sacred partitions above.
3. Flash the Lineage zip from `out/target/product/perry/`.
4. Optional: MindTheGapps **arm** (not arm64). Space is tight on 16 GB.
5. Reboot system. First boots may loop — use `adb logcat` during boot and
   `/proc/last_kmsg` after crashes.

## Vendor image (oem partition)

Lineage builds `vendor.img` as an **Android sparse** image. The oem partition
needs a raw ext4 image.

**Wrong:** `dd` of sparse `vendor.img` → corrupts oem.  
**Right:**

```bash
simg2img out/target/product/perry/vendor.img /tmp/vendor-raw.img
adb reboot recovery
adb push /tmp/vendor-raw.img /sdcard/vendor-raw.img
adb shell 'umount /vendor 2>/dev/null; dd if=/sdcard/vendor-raw.img of=/dev/block/bootdevice/by-name/oem bs=1M; sync'
adb reboot
```

Use this when iterating on vendor-only changes (`m vendorimage`) without a full
zip reflash.

## Quick checks after boot

```bash
adb shell getprop ro.build.display.id
adb shell getenforce                    # expect Enforcing
adb shell dumpsys wifi | head
adb shell dumpsys media.camera | head   # cameras when bring-up allows
```

## Stock firmware

Blob base for XT1765 T-Mobile: build **NCQS26.69-64-21**. Unpack and extract
notes: [`blobs.md`](blobs.md).
