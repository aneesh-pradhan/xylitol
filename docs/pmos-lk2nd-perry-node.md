# lk2nd perry device node

**Status (2026-07-22):** ✅ **UPSTREAM + ON DEVICE as 23.1.** Perry node is in
[`msm8916-mainline/lk2nd`](https://github.com/msm8916-mainline/lk2nd) since
[`d9ce4e70`](https://github.com/msm8916-mainline/lk2nd/commit/d9ce4e70e)
(also listed under “New devices” in 23.0 notes). **lk2nd 23.1** is flashed on
this unit and validated. Local xylitol carry (`pmos/lk2nd/0001-*`,
`scripts/pmos-apply-lk2nd-perry.sh`) was **removed** after RFT.

| Item | Value |
|---|---|
| On-phone `lk2nd:version` | **`23.1-r0-postmarketos`** |
| `lk2nd:model` | Motorola Moto E4 (perry) (MSM8917) |
| `lk2nd:device` / compatible | `perry` / `motorola,perry` |
| `oem log` | `Detected device: … (compatible: motorola,perry)` — no FIXME / `-1` |
| OS through it | `7.1.3-msm89x7` Phosh, USB-net + SSH |
| pmaports | Ride **[!9076](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/merge_requests/9076)** (main/lk2nd → 23.1); edge still 22.0 until merge |
| RFT text | `artifacts/pmos-phase-b/lk2nd-23.1-rft-comment.md` |

## Why the node exists

Without a perry device node, lk2nd (`lk2nd-msm8952`) showed
**"Unknown (FIXME!)"**, logged `Failed to find matching lk2nd device node: -1`,
and could not resolve extlinux **`fdtdir /`** (Blocker A / extlinux brick class).

Upstream node (byte-identical to our historical local backport):

```
motorola-perry {
    model = "Motorola Moto E4 (perry) (MSM8917)";
    compatible = "motorola,perry";
    lk2nd,match-device = "perry";
    lk2nd,dtb-files = "msm8917-motorola-perry";
};
```

(Also an MSM8920 variant in the same commit.)

## Flash recipe (permanent update)

**Must flash from stock Motorola fastboot** (`product: perry`). Flashing `boot`
from *inside* an older lk2nd session did **not** update `lk2nd:version` on this
unit (writes reported OKAY; getvar stayed on the previous build until stock
flash).

Sacred: only `boot`. Never touch `persist` / `modemst1` / `modemst2`.

```bash
# 1) Stock aboot
timeout 8 fastboot getvar product   # expect: perry

# 2) NORMAL only — never flash FORCE as boot
NORMAL=artifacts/pmos-phase-b/lk2nd-msm8952-23.1-r0.img
MARKER='Fastboot mode was forced with compile-time flag.'
grep -aFq "$MARKER" "$NORMAL" && { echo "FATAL: NORMAL is FORCE"; exit 1; }

fastboot flash boot "$NORMAL"
# stock may print "Image not signed or corrupt" — expected when unlocked

# 3) Cold boot into lk2nd (stock "reboot bootloader" stays on aboot)
fastboot reboot
# hold Vol-Down during boot for lk2nd fastboot menu; else NORMAL auto-continues to OS

# 4) In lk2nd fastboot:
fastboot getvar product            # lk2nd-msm8952
fastboot getvar lk2nd:version      # 23.1-r0-postmarketos
fastboot getvar lk2nd:model        # Motorola Moto E4 (perry) (MSM8917)
fastboot oem log && fastboot get_staged /tmp/lk2nd-oem.log
# expect: Detected device: Motorola Moto E4 (perry) …

fastboot continue                  # boot pmOS rootfs on userdata
```

**FORCE-FASTBOOT** twin (`artifacts/pmos-phase-b/lk2nd-force-fastboot-23.1.img`):
RAM-boot only (`fastboot boot …`) for recovery; never flash as NORMAL.
Marker string: `Fastboot mode was forced with compile-time flag.`

## Build (no xylitol patch)

Until !9076 merges, use the MR APKBUILD (or temporarily set `pkgver=23.1` in
local pmaports `main/lk2nd`) **without** any perry patch:

```bash
# pmaports main/lk2nd at 23.1-r0 (MR head), no 0001-perry patch
pmbootstrap build lk2nd --arch aarch64
# extract: packages/edge/aarch64/lk2nd-msm8952-23.1-r0.apk → boot/lk2nd.img
```

FORCE (host toolchain, does not touch the apk cache):

```bash
make -C /path/to/lk2nd-23.1 -j$(nproc) lk2nd-msm8952 \
  LK2ND_VERSION="23.1-r0-postmarketos-FORCE" \
  TOOLCHAIN_PREFIX=arm-none-eabi- \
  LK2ND_FORCE_FASTBOOT=1
```

## Historical note (22.0-r3 local carry — retired)

2026-07-20: temporary backport of `d9ce4e70` onto pmaports-pinned **22.0** as
`pmos/lk2nd/0001-*` + `scripts/pmos-apply-lk2nd-perry.sh` (`pkgrel` 2→3). Validated
as `22.0-r3-postmarketos` on hardware. **Retired 2026-07-22** after 23.1 stock
flash + RFT; do not re-add.

## Relationship to the deviceinfo `fdt` pin

`deviceinfo-motorola-perry` still pins `fdt /msm8917-motorola-perry.dtb` for a
bootloader-independent guarantee. With the perry node, `fdtdir /` also works.
Keep the pin; it is harmless belt-and-suspenders.
