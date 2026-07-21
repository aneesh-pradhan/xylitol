# xylitol

Build **LineageOS 18.1** (Android 11) for the **Motorola Moto E4** (`perry`,
XT1765 / T-Mobile). This is a **meta-repo**: manifests, patches, scripts, and
docs. The LineageOS source tree stays outside the repo (default
`~/android/lineage`).

Upstream device/kernel/vendor trees come from
[moto-msm89xx](https://github.com/moto-msm89xx). Perry’s device tree is pinned
to `lineage-17.1` and forward-ported here via patches; common, kernel, and
vendor repos are already on `lineage-18.1`.

**Status (2026-07-20):** boots with UI, touch, adb, Wi-Fi, soft navbar, FM
radio, and camera open/still (preview restored by perry **0015**;
**autofocus remains open research** — OTP path **0014** broke preview).
SELinux Enforcing. RIL still in progress — see
[`docs/handoff.md`](docs/handoff.md) for the live work queue.

**Second track — postmarketOS (mainline Linux):** a separate experiment on the
same device. Boots to a mainline `7.0.9` aarch64 userspace with **display
(Ofilm panel), Wi-Fi, and USB/SSH** working. Reversible; Android untouched
(`system`/`oem`). Not a daily driver. Reproduction:
[`docs/pmos.md`](docs/pmos.md).

| Doc | Purpose |
|---|---|
| [`docs/flashing.md`](docs/flashing.md) | TWRP, flash cycle, sacred partitions |
| [`docs/blobs.md`](docs/blobs.md) | Proprietary blobs and stock unpack |
| [`docs/known-good.md`](docs/known-good.md) | Patch tips / rebuild pins |
| [`docs/porting-log.md`](docs/porting-log.md) | Chronology and root-cause notes |
| [`docs/handoff.md`](docs/handoff.md) | Maintainer session state (not the user guide) |
| [`docs/pmos.md`](docs/pmos.md) | **postmarketOS (mainline): status + reproduction guide** |
| [`docs/pmos-perry.md`](docs/pmos-perry.md) | postmarketOS plan / rationale |
| [`docs/pmos-runbook.md`](docs/pmos-runbook.md) | pmOS executor checklist |
| [`docs/pmos-ofilm-panel.md`](docs/pmos-ofilm-panel.md) | Ofilm 499 panel research (first-light confirmed) |

License: [Apache-2.0](LICENSE) for this repo’s scripts, manifests, patches, and
docs. LineageOS, moto-msm89xx trees, and proprietary blobs have their own
licenses — blobs are **not** redistributed here.

---

## What you need

- **Host:** Ubuntu 24.04+ or **26.04 LTS** (macOS cannot build Android 10+)
- **Disk:** ~200+ GB free for the Lineage tree + `out/`
- **Device:** unlocked XT1765 (`perry`), USB debugging / fastboot
- **Recovery:** TWRP for perry (build locally or use a published release from
  this repo’s Actions / Releases)
- **Blobs:** extract from the device or stock firmware (see
  [`docs/blobs.md`](docs/blobs.md))

---

## Build LineageOS 18.1

```bash
git clone https://github.com/aneesh-pradhan/xylitol.git
cd xylitol

# 1. Host packages, repo, ccache, mke2fs.conf
./scripts/setup-env.sh
source ~/.profile && source ~/.bashrc

# Optional: override setup-env’s default git identity
# GIT_USER_NAME='Your Name' GIT_USER_EMAIL='you@example.com' ./scripts/setup-env.sh

# 2. Sync Lineage 18.1 + moto-msm89xx perry trees
./scripts/sync.sh

# 3. Apply perry / common / kernel patches
./scripts/apply-patches.sh

# 4. Proprietary blobs (device via adb, or path to an unpacked stock tree)
./scripts/extract-perry.sh adb
# ./scripts/extract-perry.sh ~/android/stock-perry-NCQS26.69-64-21/tree

# 5. Build
./scripts/build.sh
# equivalent:
#   export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
#   cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug && m bacon
```

Output zip lands under `~/android/lineage/out/target/product/perry/`.

After device-tree or blob changes, prefer `m installclean` before rebuilding.
Only wipe `out/` as a last resort. Do not interrupt an in-flight `m bacon` if
you can avoid it (dirties host tooling rebuilds).

Known-good patch tips: [`docs/known-good.md`](docs/known-good.md).

---

## TWRP

```bash
./scripts/sync-twrp.sh
./scripts/apply-twrp-patches.sh
./scripts/build-twrp.sh
```

Prefer `fastboot boot twrp.img` until the ROM is stable. Details and safety
rules: [`docs/flashing.md`](docs/flashing.md).

---

## Layout

```
manifests/          Local manifests (Lineage + TWRP)
patches/            git-am series for perry, msm8937-common, kernel, twrp
scripts/            setup, sync, apply, extract, build
config/mke2fs.conf  Ubuntu 24.04+ apexer workaround (installed by setup-env)
docs/               Build/flash notes + porting history
```

Rebuild from scratch: `sync.sh` → `apply-patches.sh` → extract → `build.sh`.

---

## Warnings

- **Never** wipe or repartition `persist`, `modemst1`, or `modemst2` (EFS/IMEI).
- **Never** `dd` a sparse `vendor.img` straight to the oem partition — convert
  with `simg2img` first ([`docs/flashing.md`](docs/flashing.md)).
- Do not commit blobs, `out/`, the Lineage tree, or stock firmware into this
  repo.
- MindTheGapps (if any): use **arm**, never arm64; 16 GB eMMC is tight — many
  builds skip GApps.

---

## Device (verified)

| Field | Value |
|---|---|
| Model | XT1765 (`perry_tmo`), GSM |
| SoC | MSM8917 (Snapdragon 425) |
| Userspace | 32-bit ARM; Nougat-era vendor blobs |
| Kernel | Downstream 3.18 (Motorola), ION |
| Stock blob base | 7.1.1 `NCQS26.69-64-21` |
