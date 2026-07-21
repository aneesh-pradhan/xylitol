# Proprietary blobs (perry)

This meta-repo does **not** ship proprietary binaries. You must extract them
locally after syncing the Lineage tree.

## Sources

| Source | Notes |
|---|---|
| Device via adb | Preferred when the phone still runs a usable system/recovery |
| Stock firmware unpack | XT1765 T-Mobile final Nougat: **NCQS26.69-64-21** |
| `proprietary_vendor_motorola` | Synced by the local manifest to `vendor/motorola` — supplies shared / montana / msm8937-common blobs; **not** a full perry-only tree |

Perry has no dedicated upstream vendor repo. `BoardConfig.mk` inherits montana
vendor fragments; device-specific files still need extract.

## Safe extract (required wrapper)

`device/motorola/perry/extract-files.sh` delegates to msm8937-common, which
defaults to **`CLEAN_VENDOR=true`** and will **wipe**
`vendor/motorola/msm8937-common/proprietary/` before extracting.

Always use the wrapper (passes `-n` and `--only-target`):

```bash
./scripts/extract-perry.sh adb
# or point at an unpacked stock system tree:
./scripts/extract-perry.sh ~/android/stock-perry-NCQS26.69-64-21/tree
```

Equivalent manual invocation:

```bash
cd ~/android/lineage/device/motorola/perry
./extract-files.sh -n --only-target adb
```

If common proprietary was wiped by mistake:

```bash
cd ~/android/lineage/vendor/motorola
git checkout HEAD -- msm8937-common/proprietary/
```

## Unpacking stock (NCQS26.69-64-21)

Typical layout after download: a Motorola CFC / XML package with sparse
`system` / `oem` chunks.

Helper (from this repo):

```bash
./scripts/unpack-stock.sh /path/to/XT1765_PERRY_TMO_…_CFC.xml-or-dir \
  ~/android/stock-perry-NCQS26.69-64-21
```

Manual recipe:

1. `simg2img system.img_sparsechunk.* system.raw.img` (and likewise for oem).
2. Strip the **131072**-byte Motorola header (`MOT_PIV_FULL256`) so the ext4
   starts at 128 KiB.
3. `mount -o ro,loop` the stripped images.
4. Arrange a tree extract-files understands (often `tree/system` → mounted
   system).

Then:

```bash
./scripts/extract-perry.sh ~/android/stock-perry-NCQS26.69-64-21/tree
```

## Expectations

Stock XT1765 does not ship every path listed in older `proprietary-files.txt`
entries (partial sets are normal). Patches in this repo harden extract for that
and ship camera packaging fixes that montana/common alone do not cover.

**Do not** ship XT1765 stock `libmmcamera2_sensor_modules.so` with the
montana ISP stack (**0014** lesson / **0015** revert): preview dies with
`sensor resolution: 0x0`. Platform libs stay montana via `camera-vendor.mk`.
Stock sensor/chromatix/actuator libs remain under
`vendor/motorola/perry/proprietary/` from extract. **Camera AF is open
research** (not fixed): OTP AF needs a different approach (full stock
stack, eeprom shim, or actuator params from DAC ranges captured under
0014).

Never commit extracted blobs into xylitol.
