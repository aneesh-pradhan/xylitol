# lk2nd perry device node — build + flash

**Status (2026-07-20):** ✅ **DONE — FLASHED + VALIDATED ON HARDWARE.** Patch
built (lk2nd **r3**), flashed to `boot`, and confirmed at runtime: lk2nd now
reports `Detected device: Motorola Moto E4 (perry) (MSM8917) (compatible:
motorola,perry)` (no more "Unknown (FIXME!)" / `-1`), and pmOS boots through it
(kernel `7.0.9-msm89x7`, USB-net + SSH, `wlan0` up). Evidence in the "Flash +
validation" result block below. **Closes handoff to-do #5.**

## Why (the gap)

Perry (Moto E4, XT1765, MSM8917) had **no lk2nd device node** upstream. lk2nd
(`msm8916-mainline/lk2nd` v22.0, `lk2nd-msm8952` build) therefore:

- showed **"Unknown (FIXME!)"** and logged
  `Failed to find matching lk2nd device node: -1`;
- returned NULL from `lk2nd_device_get_dtb_hints()`, so an extlinux
  **`fdtdir /`** line could not be resolved (`"The dtb-files for this device is
  not set"`) → boot fell back to fastboot. This is the root of the whole
  extlinux bricking saga (Blocker A).

## The fix (verified against lk2nd source, tag 22.0)

Add a `motorola-perry` node to `lk2nd/device/dts/msm8952/msm8917-mtp.dts`,
alongside perry's already-present MSM8917 siblings **nora** and **hannah**:

```
motorola-perry {
    model = "Motorola Moto E4 (perry) (MSM8917)";
    compatible = "motorola,perry";
    lk2nd,match-device = "perry";
    lk2nd,dtb-files = "msm8917-motorola-perry";
};
```

How each line was confirmed in source:

| Prop | Source evidence | Effect |
|---|---|---|
| `lk2nd,match-device = "perry"` | `device/2nd/match.c` matches it against `lk2nd_dev.device`; that value is already `perry` at runtime (proven: `fastboot getvar lk2nd:device` → `perry`) | node binds |
| `model` | `device/device.c:124` reads `model` into `lk2nd_dev.model` | clears "Unknown (FIXME!)" |
| `lk2nd,dtb-files` | `device/device.c:130` → `lk2nd_dev.dtbfiles`, returned by `lk2nd_device_get_dtb_hints()`, consumed by `boot/extlinux.c` for `fdtdir` | `fdtdir /` now resolves `msm8917-motorola-perry.dtb` |

No `board-id` research needed: the generic `msm8917-mtp.dts` (msm-id 8917,
board MTP) is the DTB the primary bootloader already loads for perry (that's how
nora/hannah bind); the device-level match is done by `lk2nd,match-device`.
No panel sub-node / `match-panel` (perry ships a single Ofilm DTB — nothing to
switch), mirroring the jeter template.

## Artifacts (in this repo)

- Patch: [`../pmos/lk2nd/0001-device-add-motorola-perry-msm8917-node.patch`](../pmos/lk2nd/0001-device-add-motorola-perry-msm8917-node.patch)
- Apply/build tooling: [`../scripts/pmos-apply-lk2nd-perry.sh`](../scripts/pmos-apply-lk2nd-perry.sh)
  (injects the patch into the local pmaports `main/lk2nd` aport, bumps
  `pkgrel` 2→3 for a version tell, re-checksums)

## Build validation (done, host-side — no device)

```
./scripts/pmos-apply-lk2nd-perry.sh
pmbootstrap build lk2nd            # exit 0, cross-compiled
```

Verified by extracting the built
`packages/edge/aarch64/lk2nd-msm8952-22.0-r3.apk` and `strings lk2nd.img`:

- **present now:** `Motorola Moto E4 (perry) (MSM8917)`, `motorola,perry`,
  `perry` (match-device), `msm8917-motorola-perry` (dtb-files),
  `22.0-r3-postmarketos` (version tell).
- **siblings intact:** `msm8917-motorola-nora`, `msm8917-motorola-hannah`.
- **the shipped r2 apk had ZERO** perry references (control).

So the patch compiles and the node is embedded. Only flashing + on-device
behaviour remain.

## Flash + validation — DONE (2026-07-20)

Flashed from **stock** aboot fastboot (serial `ZY224TB8KZ`, `product: perry`) —
the documented `flash_lk2nd` path:

```
pmbootstrap flasher flash_lk2nd     # Sending 'boot' (314 KB) OKAY; Writing 'boot' OKAY
```

("Image not signed or corrupt" = the normal unlocked-Moto warning.) Rootfs
chroot confirmed `lk2nd-msm8952 V:22.0-r3` and the flashed `lk2nd.img` embeds the
perry strings.

Runtime evidence (rebooted into lk2nd fastboot, serial `24b071b`):

- `fastboot getvar lk2nd:version` → **`22.0-r3-postmarketos`** (our build),
  `product: lk2nd-msm8952`.
- `fastboot oem log` → **`Detected device: Motorola Moto E4 (perry) (MSM8917)
  (compatible: motorola,perry)`** — the node matched; the old
  `Failed to find matching lk2nd device node: -1` / "Unknown (FIXME!)" is gone.
  (Log also shows `androidboot.device=perry`, panel
  `qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`, `sku=XT1765` — our exact unit.)
- `fastboot continue` → pmOS boots: USB-net up, `ssh xylitol@172.16.42.1` →
  `Linux 7.0.9-msm89x7`, `up 0 min`, `wlan0` present. **New lk2nd boots the OS
  cleanly (no regression).**

Sacred `persist`/`modemst*` untouched; only `boot` (lk2nd) was written.

## Device-side flash + validate — runbook (executed above; kept for reproducibility)

**Rules:** reflashes the **`boot`** partition (where lk2nd lives) — reversible
(handoff E-8: Lineage boot backup + stock fastboot). **Never** touch
`persist`/`modemst1`/`modemst2`. lk2nd runs from RAM once loaded, so overwriting
`boot` while in lk2nd fastboot is safe. Requires physical volume-key holds —
this is why it is not automated.

1. **Enter lk2nd fastboot:** power off (hold Power ~10–15 s), then hold
   **Vol-Down + tap Power**. Confirm:
   `timeout 8 fastboot getvar product` → `lk2nd-msm8952`
   (lk2nd USB serial is `24b071b`; stock aboot serial is `ZY224TB8KZ`).
2. **Grab the BEFORE log (optional evidence):** `fastboot oem log` then
   `fastboot get_staged /tmp/lk2nd-before.log` — expect the `-1` "no matching
   device node" line.
3. **Flash our r3:** `pmbootstrap flasher flash_lk2nd` — writes the locally
   built `lk2nd-msm8952-22.0-r3` (the perry-node build) to `boot`. The
   "Image not signed or corrupt" line is the normal unlocked-Moto warning.
   **STOP and report if** it errors or refuses; do not force.
4. **Verify the running lk2nd is ours:** reboot to lk2nd fastboot again
   (Vol-Down + Power) →
   - `fastboot getvar lk2nd:version` → **`22.0-r3-postmarketos`** (our build).
   - On-screen identity now reads **"Motorola Moto E4 (perry)"**, not
     "Unknown (FIXME!)".
   - `fastboot oem log` → the `Failed to find matching lk2nd device node: -1`
     line is **gone**.
5. **Confirm normal boot still works:** `fastboot continue` (or reboot). pmOS
   should boot as before (the durable `fdt` deviceinfo fix is still in place, so
   this is belt-and-suspenders). **STOP and report if it does not boot** —
   roll back per handoff E-8.
6. **(optional) Prove the node fixes `fdtdir`:** temporarily set the boot line
   back to `fdtdir /` (loop-mount `pmOS_boot`, edit `extlinux/extlinux.conf`),
   reboot; with the perry node it should now resolve `msm8917-motorola-perry.dtb`
   and boot (where it previously bricked). Restore `fdt` after. This is the
   direct proof of the node's dtb-hint; skip if you don't want to disturb the
   working boot line.

## Already upstream — this is a backport, not a new contribution (no PR)

Checked 2026-07-20: perry is **already in lk2nd upstream `main`**, added by
[`d9ce4e70`](https://github.com/msm8916-mainline/lk2nd/commit/d9ce4e70e)
(2026-04-09, "dts: msm8917 & msm8920: add support for the Motorola Moto E4
(perry)"). The upstream node is **byte-for-byte identical** to ours (same
`model` / `compatible` / `lk2nd,match-device` / `lk2nd,dtb-files`) — independent
derivation, same result, which corroborates correctness. Upstream also covers
the msm8920 variant.

It is simply **not in the released `22.0` tag** that pmaports pins (`main` is
~96 commits ahead of `22.0`). So **no upstream PR is warranted** — our
`pmos/lk2nd/0001-*` patch is a **temporary backport** of `d9ce4e70` onto the
22.0-pinned build. **Drop the patch + the `pkgrel` bump** once pmaports bumps
`lk2nd` to a release that includes `d9ce4e70` (or once we base the build on
upstream `main`); the carry becomes redundant then.

## Relationship to the deviceinfo `fdt` fix

The deviceinfo pin (`deviceinfo-motorola-perry`) already makes boot durable by
emitting an explicit `fdt`. This device node is the **complementary upstream-shaped
fix**: it makes lk2nd resolve `fdtdir` on its own *and* fixes device identity.
Both can coexist; neither depends on the other. The node is already upstream
(`d9ce4e70`); once a pmaports lk2nd release carries it, this node ships for free
and the deviceinfo pin becomes optional (but harmless — keep it as the portable,
bootloader-independent guarantee).
