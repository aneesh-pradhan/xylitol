# postmarketOS on perry — research & plan

**Date:** 2026-07-20 (updated same day: Phases B–D done; Ofilm panel open)  
**Status:** EXECUTING — Phases **B, C, C½, D complete**. Kernel carry
7.0.9-r1 (PR #48 DTS + Tianma panel #6) is built and installed into the
exported rootfs. lk2nd smoke passed; Lineage intact.
**Open blocker for display:** this XT1765 is **Ofilm 499**, not Tianma —
see dedicated research brief [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md).
**Executor instructions:** [`pmos-runbook.md`](pmos-runbook.md).
**Phase E flash still gated on explicit user approval.**

LineageOS 18.1 remains the Android daily-driver track
([`handoff.md`](handoff.md)). This file is the Linux-on-phone side quest
for the same XT1765 hardware.

Wiki (context, not gospel for our SKU):

- [Motorola Moto E4 (motorola-perry)](https://wiki.postmarketos.org/wiki/Motorola_Moto_E4_(motorola-perry))
- [Generic MSM89x7 (qcom-msm89x7)](https://wiki.postmarketos.org/wiki/Generic_MSM89x7_(qcom-msm89x7))

---

## 1. Goals / non-goals

**Goals**

- Boot **postmarketOS** on XT1765 (`perry_tmo`, serial `ZY224TB8KZ`) via
  the official mainline **`qcom-msm89x7`** path.
- Document blockers (missing perry DTB / panel) and a phased bring-up
  that can be executed later without rediscovering this research.
- Keep findings that help Lineage (especially PR #48’s hardware map)
  linked from [`porting-log.md`](porting-log.md).

**Non-goals**

- Not a LineageOS replacement for daily Android use.
- No blob reuse from pmOS into Lineage 18.1 (different kernel ABIs /
  drivers entirely — ION/mdss/KGSL/prima vs DRM/freedreno/wcn36xx).
- Lineage **camera AF** stays **open research** on the Android track
  (preview/still via perry **0015**; OTP **0014** broke preview). pmOS
  does not fix that.
- No unprompted implementation: host setup, flashes, or kernel packaging
  wait for an explicit go-ahead after this doc.

---

## 2. Hardware identity (our phone)

| Field | Value |
|---|---|
| Model | XT1765 (T-Mobile / `perry_tmo`), GSM |
| Serial | `ZY224TB8KZ` |
| Codename | perry |
| SoC | **MSM8917** (Snapdragon 425) — not MSM8920 |
| Mainline DTB to use | `msm8917-motorola-perry.dtb` (from PR #48) |
| **Panel (this unit)** | **Ofilm 499** (`lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`). Not Tianma — see [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) |

**Wiki caveats (do not copy blindly):**

- The perry wiki page lists chipset **MSM8920** and some sensor notes
  aimed at **XT1766**. Our device is **XT1765 / MSM8917**.
- PR
  [#48](https://github.com/msm89x7-mainline/linux/pull/48) carries both
  `msm8917-motorola-perry.dts` and `msm8920-motorola-perry.dts`; lk2nd
  already knows both names. Pick the **8917** DTB for this phone
  (`qcom,board-id` entries in that PR).

---

## 3. Two stacks compared

### Mainline — **chosen** target

| Layer | Package / component |
|---|---|
| Device | `device-qcom-msm89x7` (testing) — codename **`qcom-msm89x7`**, not `motorola-perry` |
| Kernel | `linux-postmarketos-qcom-msm89x7` **6.19.5-r0** from `msm89x7-mainline/linux` tag `v6.19.5-r0` |
| Bootloader chain | Stock aboot → **`lk2nd-msm8952`** (required) → mainline kernel |
| SoC helpers | `soc-qcom-msm89x7` |
| Firmware | `firmware-qcom-msm89x7` (+ `msm-firmware-loader`); may need perry WCNSS NV later |

This is what the perry and generic MSM89x7 wikis document as the current
install path.

```text
stock aboot  -->  lk2nd (boot partition)  -->  linux-postmarketos-qcom-msm89x7
                      |                              |
                      +-- selects panel DTB ---------+
                                                     v
                                              pmOS rootfs
```

### Downstream — **reference only** (legacy)

| Layer | Notes |
|---|---|
| Device | `device-motorola-perry` under `device/downstream/` in official pmaports |
| Kernel | `linux-motorola-perry` **3.18.140** (`moto-msm8937-archive`) + `mdss-fb-init-hack` / `msm-fb-refresher` |
| Firmware | `firmware-motorola-perry` / WCNSS NV still useful as a reference for NV paths |

Historical trees (for archaeology, not the build target):

- [pmaports `device-motorola-perry` @ b1dfbf63](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/tree/b1dfbf6361c3702b73820a0068dc4ba7f9f9a878/device/testing/device-motorola-perry)
  — early testing devicepkg; later moved to **downstream** (2025-05).
- [r00t `linux-motorola-perry`](https://gitlab.postmarketos.org/r00t/pmaports/-/tree/master/device/downstream/linux-motorola-perry)
  — same APKBUILD shape as official downstream 3.18.140.

The perry wiki says the device now runs **mainline** and install uses the
**generic** package. Do not default to the downstream 3.18 path.

---

## 4. Boot / flash model

1. Stock Motorola **aboot** stays as the primary bootloader (already
   unlocked on this device).
2. Flash **lk2nd** (`lk2nd-msm8952`) to the **`boot`** partition.
3. Reboot into **lk2nd’s fastboot** (secondary).
4. From lk2nd fastboot, flash the pmOS **rootfs** (and related images per
   pmbootstrap / wiki instructions).
5. lk2nd selects the panel/board **DTB**; without lk2nd, panel selection
   fails → black screen. Wiki warns: flashing rootfs **without** lk2nd
   can soft-brick.

Debug aids if needed later: TWRP for `pstore` / `console-ramoops`; USB
network + SSH once userspace is up.

**Lineage restore after a pmOS experiment:** reflash Lineage `boot` +
system/vendor (oem) / userdata images from a TWRP backup or from
`m bacon` outputs — see [`flashing.md`](flashing.md). lk2nd **displaces**
the Lineage boot image until restored.

---

## 5. Sacred partitions

Same rules as the Lineage port ([`flashing.md`](flashing.md),
[`CLAUDE.md`](../CLAUDE.md)):

- **Never** wipe, repartition, or `dd` over `persist`, `modemst1`, or
  `modemst2` (EFS / IMEI). Off-device TWRP backups of these already exist.
- **Before** flashing lk2nd: take a **full TWRP backup** of at least
  `boot`, `system`, `vendor`/`oem`, and `userdata` (plus the sacred
  partitions if not already backed up off-device).
- Prefer reversible steps (`fastboot boot` where possible) before
  permanent `boot` displacement.
- If a script or pmbootstrap step could touch EFS, **stop and ask**.

---

## 6. Blockers & work items before first boot

**Blocker #1 — perry DTB missing from the packaged kernel**
*(2026-07-20 update: upstream package is now **7.0.9-r0**, still no perry
DTB; the local carry described below is implemented in
`../pmos/linux-postmarketos-qcom-msm89x7/` and building — see
[`pmos-runbook.md`](pmos-runbook.md).)*

| Piece | Upstream today | Gap for XT1765 |
|---|---|---|
| Kernel pkg | `linux-postmarketos-qcom-msm89x7` **6.19.5-r0** | **No perry DTB in that tag** |
| Perry DTS | Open draft PR [#48](https://github.com/msm89x7-mainline/linux/pull/48) (fork head noted in research: `b87b04a9`): `msm8917-motorola-perry.dts` + common dtsi + MSM8920 variant | **Unmerged**; maintainer wants rpmcc / 8920 upstream first |
| Panel | Open [linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6) (`motorola,perry-499v1-tianma`) | **Unmerged**; carried locally as 0004. **Insufficient for this XT1765** — unit is Ofilm (see Blocker #2) |
| lk2nd | `lk2nd-msm8952`; DTS already maps `motorola-perry` → perry DTBs | Required; without it, panel selection fails. **Phase D verified** on this phone |

**Blocker #2 — XT1765 is Ofilm 499, carry is Tianma-only** *(discovered
Phase D, 2026-07-20)*

lk2nd reported
`lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`. Downstream
3.18 has matching
`dsi-panel-mot-ofilm-499-720p-video*.dtsi` (plus Tianma/BOE/INX variants).
No Ofilm mainline driver in our overlay yet. Full research tasking:
[`pmos-ofilm-panel.md`](pmos-ofilm-panel.md).

**Do not** expect stock `pmbootstrap init` → vendor `qcom` / device
`msm89x7` alone to boot this XT1765 until the kernel package includes the
perry DTB **and an Ofilm-matching panel driver** (Tianma-only will likely
black-screen).

**Work items (when implementing — not now)**

1. Carry PR #48 DTS **and** panel PR #6 into a **local**
   `linux-postmarketos-qcom-msm89x7` fork / APKBUILD bump — do not wait
   blindly on upstream merge.
2. Verify the built package ships
   `/boot/dtbs/qcom/msm8917-motorola-perry.dtb`.
3. Confirm lk2nd enumerates perry and picks that DTB.
4. Firmware: start with `firmware-qcom-msm89x7` (montana/cedric WCNSS
   paths today); if Wi-Fi fails, compare old
   `firmware-motorola-perry` WCNSS NV.
5. First UI: **`console`** (or equivalent minimal) + SSH over USB for
   bring-up. Optional Phosh/Xfce later (wiki historically showed xfce4).

---

## 7. Expected feature matrix

Copied from the perry wiki status as of research day, marked
**unverified on XT1765** until we boot this unit.

| Feature | Wiki (generic / perry page) | XT1765 (`ZY224TB8KZ`) |
|---|---|---|
| USB | Y | unverified |
| Touch | Y | unverified |
| Screen | Y | **at risk** — Ofilm panel, Tianma driver only ([`pmos-ofilm-panel.md`](pmos-ofilm-panel.md)) |
| Wi-Fi | Y | unverified (may need perry NV) |
| Bluetooth | Y | unverified |
| Audio | Y | unverified |
| 3D / GPU | Y | unverified |
| Battery / charging | Y | unverified |
| OTG | Y | unverified |
| Calls / SMS / data | P (partial) | unverified |
| Camera | N | unverified (expect broken) |
| Kernel (wiki) | 6.19.5 | pkg lacks perry DTB until local carry |

---

## 8. Host setup (when implementing)

- **Ubuntu side only** (same dual-boot host as Lineage builds). Do not
  build pmOS on macOS.
- Install / use **pmbootstrap** from postmarketOS **edge** (follow current
  upstream docs when the time comes).
- Workdir: **outside** xylitol and **outside** `~/android/lineage`
  (e.g. `~/pmos` or similar). Keep xylitol as the meta-repo/docs home.
- Never commit proprietary firmware, extracted NV, or pmbootstrap chroots
  into xylitol.
- Sacred partition rules still apply when the device is attached.

---

## 9. Phased execution (later, after explicit approval)

| Phase | What | Gate |
|---|---|---|
| **A** | This documentation | **Done (2026-07-20)** |
| **B** | Host packages + `pmbootstrap init` for `qcom` / `msm89x7` — **no flash** | **Done (2026-07-20)** — `~/pmos/`, expect script `~/pmos/init-perry.exp` |
| **C** | Custom kernel APKBUILD: carry PR #48 + panel PR #6 on v7.0.9-r0; verify DTB path in package | **Done** — 7.0.9-r1 apk; runbook §1 |
| **C½** | `ssh_keys` + `pmbootstrap install` + export | **Done** — runbook §2 |
| **D** | Smoke: `fastboot boot lk2nd.img`; TWRP backups first | **Done** — perry detected; **Ofilm panel discovered**; runbook §3 |
| **E** | `flash_lk2nd` → verify lk2nd fastboot → `flash_rootfs` (userdata; kills Android data) → console + SSH | **Explicit user go-ahead** — runbook §4; prefer Ofilm driver first |
| **F** | Feature checklist on XT1765; feed results back into [`porting-log.md`](porting-log.md) | After E — runbook §5 |

Defaults locked for later implementation:

- **Stack:** mainline `qcom-msm89x7` (not downstream 3.18).
- **First UI:** console / SSH, then optional DE.
- **Flash policy:** full TWRP backup first; never touch EFS; treat lk2nd
  as displacing Lineage boot until restored.
- **Kernel strategy:** local carry of PR #48 + panel PR #6 until upstream
  tags include them.

---

## 10. Relation to LineageOS 18.1

| Topic | Verdict |
|---|---|
| Source trees | Orthogonal. pmOS workdir ≠ `~/android/lineage`. |
| Kernel | Mainline cannot drive Nougat 32-bit HALs; Lineage stays on downstream 3.18 (+ parked staging-4.9 quest). |
| Cross-pollination | PR #48 DTS is still the best public map of perry hardware for Android HAL / sepolicy debugging. |
| staging-4.9 Lineage kernel | Remains parked ([`kernel-4.9-plan.md`](kernel-4.9-plan.md)); unrelated to this pmOS path. |
| Camera AF on Lineage | Open research; unchanged by this side quest. |
| When to implement | Only when the user asks — not unprompted after RIL/AF. |

Earlier recon (2026-07-19) lives in [`porting-log.md`](porting-log.md)
(“msm89x7-mainline org research”). This file supersedes the “parked
forever” framing for pmOS: the plan is documented; execution is still
gated.

---

## Quick reference links

- Device wiki: <https://wiki.postmarketos.org/wiki/Motorola_Moto_E4_(motorola-perry)>
- Generic MSM89x7: <https://wiki.postmarketos.org/wiki/Generic_MSM89x7_(qcom-msm89x7)>
- Kernel PR #48: <https://github.com/msm89x7-mainline/linux/pull/48>
- Panel PR #6 (Tianma only): <https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6>
- **Ofilm panel research brief:** [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md)
- lk2nd (live): `msm8916-mainline/lk2nd` — org’s own `msm89x7-mainline/lk2nd` is archived
- Lineage flash / sacred rules: [`flashing.md`](flashing.md)
- Live Android work queue: [`handoff.md`](handoff.md)
