# Perry custom device tree + kernel (in-repo) — plan & performance backlog

**Date:** 2026-07-21  
**Track:** postmarketOS (primary). Lineage 3.18 / staging-4.9 stay out of
scope here — different ABI, different goals.  
**Status:** In-repo **device + custom kernel packages are the active work**.
Phase B image was built (P0 included); **hardware flash is parked** (lk2nd
userdata write hung / device wedged — do not resume unless asked). **P1
repo-side work is largely done** (defconfig scrub, eMMC udev, cpufreq audit);
P1.3 / P1.5 wait on device measurement or initramfs polish.

---

## 1. Why graduate from overlays

Today perry rides the **generic** `qcom-msm89x7` device package plus local
carries under `pmos/`:

| Piece | Current home |
|---|---|
| DTS + panels | `pmos/linux-postmarketos-qcom-msm89x7/0001–0006` patches |
| Boot `fdt` pin + linger | `pmos/deviceinfo-motorola-perry` |
| Wi-Fi NV | `pmos/firmware-motorola-perry-nv` |
| Audio UCM | `pmos/alsa-ucm-motorola-perry` |
| lk2nd node | `pmos/lk2nd/0001-*` |

That worked for bring-up. It does **not** scale for:

- A perry-tuned **defconfig** (drop unused SoC family options, tighten debug)
- DT / cpufreq / thermal / GPU opp **performance** work without fighting the
  generic multi-device package
- A first-class `pmbootstrap init` codename (`motorola-perry`) instead of
  `qcom-msm89x7` + `--add` soup
- Clear ownership: “this repo’s perry port” vs “temporary overlay on upstream”

**Non-goal:** vendoring the full Linux git tree into xylitol (multi‑GB). The
kernel stays an **aport**: upstream tarball + patches + config, same model as
pmaports.

---

## 2. Proposed in-repo layout

```
pmos/
  device-motorola-perry/          # FIRST-CLASS device package
    APKBUILD
    deviceinfo                    # name/codename/dtb=perry only
    modules-initfs
    README.md
  linux-motorola-perry/           # CUSTOM kernel aport (perry-focused)
    APKBUILD
    config-motorola-perry.aarch64 # starts from msm89x7, then tuned
    patches/                      # carry 0001–0006 + future perf/DT
    README.md
  # existing keeps working until cutover:
  linux-postmarketos-qcom-msm89x7/
  deviceinfo-motorola-perry/
  firmware-motorola-perry-nv/
  alsa-ucm-motorola-perry/
  lk2nd/
docs/
  perry-custom-kernel-plan.md     # this file
scripts/
  pmos-apply-device-perry.sh
  pmos-apply-kernel-perry.sh
```

### Device package responsibilities

`device-motorola-perry` should eventually `depends=` on:

- `linux-motorola-perry` (not the generic msm89x7 kernel)
- `lk2nd-msm8952` (+ our perry node carry until upstream pkgrel catches up)
- `firmware-qcom-msm89x7`, `firmware-qcom-adreno-a300`, `msm-firmware-loader`
- `firmware-motorola-perry-nv`
- `alsa-ucm-motorola-perry`
- `soc-qcom-msm89x7`, `postmarketos-base`, …

`deviceinfo` pins **only** `qcom/msm8917-motorola-perry` (no multi-SoC glob) —
supersedes the standalone `deviceinfo-motorola-perry` override once cut over.

### Kernel package responsibilities

`linux-motorola-perry`:

- Same upstream as today: `msm89x7-mainline/linux` tag (currently `v7.0.9-r0`)
- Absorb existing perry patches (0001–0006) under `patches/`
- Own a **perry defconfig** derived from `config-postmarketos-qcom-msm89x7`
- Grow performance / DT patches as numbered series (`0100-perf-…`)

Cutover path: apply scripts → `pmbootstrap build` both →
`pmbootstrap init` vendor `motorola` / device `perry` **or** keep building
via `qcom-msm89x7` with `extra_packages` until a full deviceaport is registered
in local pmaports.

---

## 3. Hardware budget (optimization targets)

| Resource | Reality on XT1765 |
|---|---|
| SoC | MSM8917 — 4× Cortex-A53 @ ≤1.4 GHz |
| GPU | Adreno 308 (freedreno / mesa) |
| RAM | **2 GB** LPDDR3 — Phosh is tight |
| Storage | 16 GB eMMC |
| Display | 720×1280 DSI (Ofilm 499v0) |
| Kernel | Mainline-ish 7.0.9-msm89x7, aarch64 |

Optimizations that ignore RAM pressure or thermal on this chip are noise.

---

## 4. Performance & optimization backlog

Prioritized for **felt** UX on a 2 GB Phosh phone. Each item lists layer,
expected win, risk, and deps.

### P0 — biggest bang / lowest regret (userspace + easy kernel)

| # | Item | Layer | Win | Risk | Notes |
|---|---|---|---|---|---|
| P0.1 | **zram** (lz4/zstd) 25–50% of RAM | userspace | Less reclaim thrash under Phosh | Low | `zram-init` / systemd zram generator; measure PSI / majfault |
| P0.2 | Trim Phosh recommends | userspace | Free RAM + flash | Low | `pmbootstrap install --no-recommends` or deny-list heavy apps (firefox-esr optional) |
| P0.3 | `WLR_DRM_NO_ATOMIC=1` for phoc if glitches | userspace | Stops rare DSI EBUSY freezes | Low | Env drop-in; already documented fallback |
| P0.4 | Disable unused session services | userspace | CPU + RAM | Low | flatpak, cups, fprintd, tuned-ppd if unused |
| P0.5 | USB gadget autosuspend policy | userspace | Stable SSH while iterating | Low | Host `nmcli … managed no` + device autosuspend tweak |

### P1 — kernel / DT (custom kernel series)

| # | Item | Status | Layer | Notes |
|---|---|---|---|---|
| P1.1 | **Production defconfig scrub** | ✅ 2026-07-21 | kernel config | Dropped function tracer / dynamic ftrace (kept `FTRACE`/tracepoints), `DYNAMIC_DEBUG`, `FW_LOADER_DEBUG`, `CIFS_DEBUG*`, `BLK_DEBUG_FS`; disabled non-perry Motorola/Xiaomi panel modules (kept Ofilm + Tianma). Alpine/clang options preserved (no host `olddefconfig`). `linux-motorola-perry` **pkgrel=1**. |
| P1.2 | CPUFreq / schedutil tuning | ✅ audited | DT + config | `msm8917.dtsi` already has OPPs 960 / 1094.4 / 1248 / 1401.6 MHz + cooling-cells; perry enables `&gpu`; default gov **schedutil**. No DT patch until on-device baselines. |
| P1.3 | GPU opp / cooling | ⏳ needs device | DT + mesa | Profile after flash resumes; reserved `0101` in patches README. |
| P1.4 | eMMC: MQ / scheduler | ✅ udev | udev | `60-perry-emmc-scheduler.rules` → `mq-deadline` on `mmcblk0`; `device-motorola-perry` **pkgrel=2**. |
| P1.5 | Earlier DRM console / shorter splash | ⏳ later | initramfs + DRM | Initramfs fb wait (handoff #6); not started. |
| P1.6 | Reduce kernel timer / tick noise | ✅ with P1.1 | config | `HZ` **300 → 250**; left `NO_HZ_IDLE` (no `NO_HZ_FULL` on 4‑core phone). |

### P2 — power & sustained performance

| # | Item | Layer | Win | Risk |
|---|---|---|---|---|
| P2.1 | Wi-Fi powersave vs latency (`iw`/`NetworkManager`) | userspace | Battery | Low |
| P2.2 | Modem runtime PM once SIM/MM works | userspace + DT | Battery | Med |
| P2.3 | Display idle / backlight curves | DT + phosh | Battery | Low |
| P2.4 | Thermal trip points vs stock | DT | Sustained clocks | Med — validate with stress + skin temp |
| P2.5 | Compiler: LLVM ThinLTO kernel | build | Code quality / size | High build cost |

### P3 — stretch (only after P0–P1 measured)

| # | Item | Notes |
|---|---|---|
| P3.1 | Enable cameras in DT + libcamera | Huge work; currently disabled |
| P3.2 | Sensors (prox/ALS/vibrator) | Feature, not speed |
| P3.3 | Upstream perry deviceaport to pmaports | Exit generic msm89x7 |
| P3.4 | Revisit staging-4.9 **Lineage** kernel | Parked; Android-only; see `kernel-4.9-plan.md` |

---

## 5. Measurement plan (do this before claiming wins)

Baseline on device (USB-net or Wi-Fi SSH), Phosh idle + cold boot:

```bash
# Boot time
systemd-analyze
systemd-analyze blame | head

# RAM
free -h
ps aux --sort=-%mem | head -20

# CPU / sched
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Storage
cat /sys/block/mmcblk0/queue/scheduler
```

Record numbers in `docs/porting-log.md` with date before/after each P0/P1 change.

---

## 6. Phased execution

| Phase | Deliverable | Gate |
|---|---|---|
| **A** | Scaffold `device-motorola-perry` + `linux-motorola-perry` in xylitol | ✅ DONE |
| **B** | Apply scripts; build kernel+device; Phosh image staged | ✅ build DONE; **flash PARKED** 2026-07-21 |
| **C** | P0 userspace (zram pct, `--no-recommends`, WLR env, USB udev, presets) | ✅ in device package + Phase B image recipe |
| **D** | P1 defconfig scrub + eMMC udev + cpufreq audit | ✅ repo-side DONE; P1.3/P1.5 + on-device metrics still open |
| **E** | Optional upstream deviceaport / drop generic msm89x7 dependency | Community readiness |

---

## 7. Relationship to existing overlays

- **Canonical DT/panel patches + defconfig:** `pmos/linux-motorola-perry/`.
- Legacy published path (`qcom-msm89x7` + `pmos-build-phosh-release.sh`) still
  works; `pmos-apply-perry-kernel.sh` copies patches **from**
  `linux-motorola-perry/patches/` into the generic msm89x7 aport.
- `deviceinfo-motorola-perry` remains for the overlay path; first-class
  `device-motorola-perry` embeds the fdt pin + linger + P0 drop-ins.
- Cutover (release script → `motorola-perry`) is optional and separate from
  keeping the custom kernel tree healthy in-repo.

Lineage patches under `patches/device/motorola/perry` and
`patches/kernel/motorola/msm8953` remain the **Android** track — do not mix
into this mainline custom kernel.

---

## 8. Open decisions (resolved at Phase B)

1. **Codename:** ✅ `pmbootstrap config device motorola-perry` (local testing aport).
2. **Config strategy:** ✅ full copied defconfig seeded from msm89x7; **P1.1 scrubbed**.
3. **Release lean:** ✅ `--no-recommends` in `scripts/pmos-build-phase-b.sh`.

**Archived conflict:** upstream `device/archived/{device,linux}-motorola-perry`
(3.18 downstream) share pkgnames — apply scripts `rm -rf` those from the local
pmaports checkout only so `device/testing/` wins.
