# Research brief — perry Ofilm 499 panel (pmOS)

**Date:** 2026-07-20  
**Audience:** research / discovery agent (read-only preferred until
implementation is approved).  
**Parent track:** postmarketOS on XT1765 — [`pmos-perry.md`](pmos-perry.md),
executor runbook [`pmos-runbook.md`](pmos-runbook.md).  
**Status:** **RESEARCH DONE, DRIVER IMPLEMENTED 2026-07-20** (user approved
implementation; see §7 findings). Phase E flash remains gated on explicit
user go-ahead. LineageOS remains the daily-driver track.

---

## 0. One-paragraph situation

pmOS Phase B → D are done on this XT1765 (`ZY224TB8KZ`). The local kernel
carry (`pmos/linux-postmarketos-qcom-msm89x7/`, 7.0.9-r1) ships
`msm8917-motorola-perry.dtb` and a **Tianma** 499v1 panel module from
[linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6).
lk2nd smoke (`fastboot boot`, nothing flashed) proved the board is
**perry**, but reported panel
`qcom,mdss_dsi_mot_ofilm_499_720p_video_v0` — this unit is the **Ofilm**
499 variant, not Tianma. First real pmOS boot will likely get USB/SSH
with a **black screen** until an Ofilm DRM panel driver exists and the
DTS `compatible` matches (or lk2nd can select among panel variants).

---

## 1. Verified facts (do not re-litigate)

| Fact | Evidence |
|---|---|
| Device | XT1765 / `perry` / MSM8917 / serial `ZY224TB8KZ` |
| lk2nd runs via `fastboot boot` (no flash) | Phase D; Lineage still boots after |
| lk2nd device id | `lk2nd:device:perry` |
| lk2nd panel id | **`lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`** |
| Full getvar dump | `~/android/backups/perry/lk2nd-getvar-all.txt` |
| Current DTS panel node | `compatible = "motorola,perry-499v1-tianma"` in patch 0003 |
| Current panel .ko | `panel-motorola-perry-499v1-tianma` (patch 0004) |
| Downstream has Ofilm MDSS panel | `kernel/.../dsi-panel-mot-ofilm-499-720p-video*.dtsi` |
| Downstream also has Tianma / BOE / INX 499 | same `dts/qcom/` dir — perry is multi-panel |
| `msm8917-perry-common.dtsi` includes both Tianma + Ofilm | pref-prim defaults to Tianma `v1`; runtime select is MDSS |

Exact lk2nd lines of interest:

```
(bootloader) product:lk2nd-msm8952
(bootloader) lk2nd:version:22.0-r2-postmarketos
(bootloader) lk2nd:device:perry
(bootloader) lk2nd:bootloader:0xBA34
(bootloader) lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0
(bootloader) serialno:ZY224TB8KZ
```

---

## 2. What is already built (host)

| Item | Path / note |
|---|---|
| pmbootstrap | `~/bin/pmbootstrap` → `~/pmos/pmbootstrap` (3.11.1) |
| Kernel overlay (xylitol) | `pmos/linux-postmarketos-qcom-msm89x7/` |
| Apply script | `scripts/pmos-apply-perry-kernel.sh` |
| Live pmaports pkg | `~/pmos/work/cache_git/pmaports/device/testing/linux-postmarketos-qcom-msm89x7` |
| Built apk | `linux-postmarketos-qcom-msm89x7-7.0.9-r1.apk` |
| Export | `/tmp/postmarketOS-export/` (`lk2nd.img`, `qcom-msm89x7.img` ~1.28 GiB) |
| Lineage rollback boot | `~/android/backups/perry/lineage-boot-2026-07-20.img` |
| TWRP BD backup | `~/android/backups/perry/twrp-pmos-pre-D-20260720-1656/` |
| sdcard pull | `~/android/backups/perry/sdcard-pre-D/` |

SSH: host key `~/.ssh/id_ed25519` baked into the install image (`ssh_keys True`).
User password on image: **set** (dummy; prefer key).

---

## 3. Research questions (answer these)

Priority order:

1. **Does an Ofilm 499 mainline/panel-drivers config already exist?**
   Search `msm89x7-mainline/linux-panel-drivers`, PR discussions on
   [#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6)
   and linux [#48](https://github.com/msm89x7-mainline/linux/pull/48),
   and any `*ofilm*499*` / `mipi_mot_video_ofilm*` hits. Tianma-only so
   far in our tree.

2. **How does lk2nd map `lk2nd:panel=…` to a DTB / panel compatible?**
   Document the exact mechanism for msm89x7/perry (panel-specific DTBO
   vs cmdline vs single DTB with one hardcoded panel). This decides
   whether we need:
   - one Ofilm DTB replacing Tianma in 0003, or
   - dual DTBs / panel selection like other multi-panel Motos.

3. **Can we generate the Ofilm driver with `lmdpdg` from stock MDSS DTSI?**
   Primary source (downstream 3.18, already in the Lineage tree):

   | File | Role |
   |---|---|
   | `~/android/lineage/kernel/motorola/msm8953/arch/arm/boot/dts/qcom/dsi-panel-mot-ofilm-499-720p-video.dtsi` | Node `qcom,mdss_dsi_mot_ofilm_499_720p_video_v0` (matches lk2nd string) |
   | `…/dsi-panel-mot-ofilm-499-720p-video-common.dtsi` | Timing, reset seq, `qcom,mdss-dsi-on-command`, supplier `ofilm` |
   | Stock unpack (optional alt) | `~/android/stock-perry-NCQS26.69-64-21/` |

   Tianma reference workflow: panel-drivers#6 was generated with
   `lmdpdg --dumb-dcs`, then our 0004 was converted to
   `mipi_dsi_multi_context` / `*_multi()` for v7.0.9 (see porting-log
   2026-07-20 panel API fix). **Any new Ofilm driver must use the
   multi_context API** — do not ship the old `mipi_dsi_dcs_write_seq`
   style.

4. **Timings: Ofilm vs Tianma** — are they close enough that a wrong
   driver still lights the panel, or hard-fail? Compare porch/clock/on-command
   between ofilm-common and tianma-common dtsi. Record a short table.

5. **Suggested compatible string** for mainline, e.g.
   `motorola,perry-499-ofilm` (align with existing
   `motorola,perry-499v1-tianma` naming). Flag any upstream naming
   convention from sibling panels (montana, jeter, etc.).

6. **Touch firmware side note (out of scope unless free):** stock has
   `synaptics-{ofilm,tianma}-*-perry.tdat`. Panel vendor ≠ touch vendor
   necessarily; do not block display research on this.

---

## 4. Implementation sketch (for after research — do not execute yet)

When the user approves implementation:

1. Add `lmdpdg` config + generated
   `panel-motorola-perry-499-ofilm.c` (or similar) under the xylitol
   overlay (new patch `0005-…` preferred over rewriting 0004).
2. Enable `CONFIG_DRM_PANEL_…_OFILM=m` in the overlay defconfig/APKBUILD.
3. Point DTS panel `@0` `compatible` at the Ofilm string **for this
   phone**, or implement lk2nd-style multi-panel selection if research
   shows that is required for upstreamability.
4. Re-apply (`scripts/pmos-apply-perry-kernel.sh`), checksum, rebuild
   kernel apk, `pmbootstrap install`, re-export.
5. Only then consider Phase E (still needs **explicit** flash go-ahead).

Mirror sibling panels in
`drivers/gpu/drm/panel/msm89x7-generated/` for API style
(e.g. `panel-motorola-montana-r63350-tianma.c`).

---

## 5. Gates & sacred rules

- **No Phase E** (`flash_lk2nd` / `flash_rootfs`) without user go-ahead.
- Never touch `persist`, `modemst1`, `modemst2`.
- Do not commit blobs, chroots, or `out/` into xylitol.
- No AI co-author trailers on commits.
- Prefer documenting findings in this file + a dated
  [`porting-log.md`](porting-log.md) section; update checkboxes in
  [`pmos-runbook.md`](pmos-runbook.md) only if status changes.

---

## 6. Deliverable expected from the research agent

A short write-up (append to this file or a new § in porting-log) covering:

1. Whether Ofilm already exists upstream / in flight.
2. lk2nd panel → DTB selection mechanism for perry.
3. Concrete generate recipe (`lmdpdg` flags, input dtsi, output paths).
4. Ofilm vs Tianma timing delta summary.
5. Recommended next implementation patch list (file names only).
6. Risk: flash E now with Tianma-only vs wait for Ofilm.

Optional: draft (not applied) `lmdpdg` config script text.

---

## 7. Findings & implementation (2026-07-20) — §6 deliverable

> **UPDATE 2026-07-20 (later): FIRST-LIGHT CONFIRMED — panel WORKS.** pmOS
> booted to userspace; on the live rootfs, DTS selects
> `compatible: motorola,perry-499v0-ofilm`, module
> `panel_motorola_perry_499v0_ofilm` loaded, `card0-DSI-1` connected+enabled
> at 720×1280, `msm_dpu` bound `1a94000.dsi`, backlight on. Visible test
> (fb white → `/dev/urandom` static → backlight blink) **user-witnessed**:
> static rendered, `perry login:` tty visible, backlight blinking. The
> risk call in §7.6 resolved favourably. Full log: porting-log 2026-07-20
> "pmOS BOOTS to userspace" → "Ofilm 499v0 panel — first-light CONFIRMED".

**Vendor sanity check first:** Ofilm (OFILM Group / O-Film Tech, Shenzhen)
is a real display-module supplier — an integrator that laminates touch onto
LCD cells rather than an LCD fab. Motorola quad-sourced the perry 499
panel: downstream has **tianma v0/v1/v2, boe v0/v1, inx v0/v1, ofilm v0**
(`dsi-panel-mot-{tianma,boe,inx,ofilm}-499-720p-video.dtsi`). The lk2nd
string matches ofilm **v0** exactly. No discrepancy — our unit is simply
Ofilm-fitted while upstream assumed Tianma.

### 7.1 Ofilm upstream status (§3 Q1)

**Does not exist upstream.** No `ofilm`/`perry` hits in
`msm89x7-mainline/linux-panel-drivers`; PR #6 discussion shows the author
was asked "does this device have only one panel variant?" and answered
they knew of no others. Our lk2nd detection is new information for
upstream — worth a comment on PR #6 / linux#48 later.

### 7.2 lk2nd panel → DTB mechanism (§3 Q2)

From `lk2nd/device/panel.c` (msm8916-mainline/lk2nd HEAD):

- lk2nd parses the downstream panel name from the stock aboot cmdline
  (`mdss_mdp.panel=…`) and exposes it as fastboot var `lk2nd:panel`.
- If lk2nd's **own device DTS** has a node with
  `compatible = "…,lk2nd,panel"`, its **subnodes are named after
  downstream panel strings**; each subnode's `compatible` is the mainline
  panel compatible. On a mainline boot, lk2nd finds the target DTB node
  matching the map node's own (placeholder) compatible and **rewrites
  its compatible** to `"<detected>", "<placeholder>"`.
- **lk2nd has no perry device DTS** (checked the tree; `lk2nd:device:perry`
  comes from cmdline parsing, not a device entry) → **no fixup happens
  for perry today; the DTB's hardcoded panel@0 compatible decides.**
- Consequence: for this unit we hardcode Ofilm in the DTS (patch 0006).
  Proper multi-panel selection = future lk2nd PR adding a perry entry
  with an `lk2nd,panel` map (tianma v0/v1/v2, ofilm v0, boe v0/v1,
  inx v0/v1) + a placeholder compatible in the mainline DTS.

### 7.3 Generate recipe (§3 Q3)

`lmdpdg` not run locally; the driver was **hand-converted** from
`dsi-panel-mot-ofilm-499-720p-video-common.dtsi` following the exact
output shape of our Tianma 0004 (multi_context API throughout,
`mipi_dsi_dcs_write_seq_multi` + `mipi_dsi_msleep`; 6-byte qcom command
headers stripped; `05`-type DCS 11/29 mapped to
`exit_sleep_mode`/`set_display_on` helpers with their DTSI delays
0x78=120 ms / 0x64=100 ms).

### 7.4 Ofilm vs Tianma delta (§3 Q4)

| Aspect | Tianma 499 v1 | Ofilm 499 v0 |
|---|---|---|
| Clock / porches / PHY timings | 510589440 Hz; HFP 128 HBP 200 HPW 20; VFP 20 VBP 20 VPW 8; timings `7C 20 14 00 46 48…` | **identical** |
| Controller IC (by init sig) | Ilitek ILI9881-style (`FF 98 81` page select) | Novatek NT35xxx-style (`FF AA 55 25`, `F0 55 AA 52 08` CMD2) |
| Init sequence | 7 commands | 29 commands incl. gamma tables (B0–B3/BC–BF), `D9`, MADCTL `36 03` |
| Display-on delay | 20 ms | 100 ms |
| Off-command, reset seq, supplies | identical | identical |

**A Tianma driver on the Ofilm panel is a hard fail** (wrong IC's CMD2
init), not a cosmetic mismatch — expect black screen, which matches the
Phase E risk note. Same the other way around.

### 7.5 Implemented patches (§3 Q5 / sketch §4)

- `0005-drm-panel-add-motorola-perry-Ofilm-499v0-panel.patch` — new
  `panel-motorola-perry-499v0-ofilm.c` + Kconfig/Makefile. Compatible
  **`motorola,perry-499v0-ofilm`** (mirrors `perry-499v1-tianma`;
  downstream ofilm only has v0).
- `0006-arm64-dts-qcom-perry-select-Ofilm-499v0-panel.patch` — panel@0
  compatible tianma→ofilm for this unit only (kept separate from 0005 so
  0005 stays upstreamable).
- `scripts/pmos-apply-perry-kernel.sh` — copies 0005/0006, adds
  `CONFIG_DRM_PANEL_MOTOROLA_PERRY_499V0_OFILM=m` (Tianma stays built).
- `APKBUILD.overlay` — pkgrel=2, sources 0005/0006.

### 7.6 Risk call (§6 #6)

Flashing Phase E with the old Tianma-only image ⇒ certain black screen
(SSH-only debug). With 0005/0006 the odds of first-light are good since
every timing number comes from the shipped MDSS DTSI. Recommended order:
non-flash `fastboot boot` smoke of the new boot image first; Phase E
flash only after panel first-light is confirmed and user approves.

---

## 8. Quick links

| Resource | URL / path |
|---|---|
| Panel generators repo | <https://github.com/msm89x7-mainline/linux-panel-drivers> |
| Tianma PR (reference) | <https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6> |
| Perry DTS PR | <https://github.com/msm89x7-mainline/linux/pull/48> |
| lk2nd | <https://github.com/msm8916-mainline/lk2nd> |
| Generic wiki | <https://wiki.postmarketos.org/wiki/Generic_MSM89x7_(qcom-msm89x7)> |
| Perry wiki | <https://wiki.postmarketos.org/wiki/Motorola_Moto_E4_(motorola-perry)> |
| Our Tianma carry | `pmos/linux-postmarketos-qcom-msm89x7/0004-*.patch` |
| Downstream Ofilm MDSS | `~/android/lineage/kernel/motorola/msm8953/arch/arm/boot/dts/qcom/dsi-panel-mot-ofilm-499-720p-video*.dtsi` |
| Session state | [`handoff.md`](handoff.md) §6 |
| Chronology | [`porting-log.md`](porting-log.md) 2026-07-20 pmOS Phase D |
