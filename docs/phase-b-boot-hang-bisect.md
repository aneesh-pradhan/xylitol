# Phase B boot-hang bisect (2026-07-21 → 2026-07-22)

**Status:** Hang **confirmed** in first-class Phase B path. Device recovered
on known-good overlay release. Isolation queue for next session below.

**Related:** [`handoff.md`](handoff.md) · [`perry-custom-kernel-plan.md`](perry-custom-kernel-plan.md) ·
[`porting-log.md`](porting-log.md)

---

## 1. Symptom

After flashing first-class `device-motorola-perry` + `linux-motorola-perry`
Phase B images (`scripts/pmos-build-phase-b.sh` + force-flash):

- Backlight turns on (~panel power).
- Screen stays **black** (no splash, no fbcon, no greeter).
- **No USB** (no gadget, no `fastboot`/`adb`, no SSH) for many minutes.
- Reproducible after power-cycle + `continue`.

Known-good **`pmos-perry-2026-07-21`** (overlay path) **boots Phosh** on
the same hardware.

---

## 2. Paths compared

| | **Known-good (boots)** | **Phase B (hangs)** |
|---|---|---|
| Device | `device-qcom-msm89x7` + `deviceinfo-motorola-perry` | `device-motorola-perry` |
| Kernel | `linux-postmarketos-qcom-msm89x7` | `linux-motorola-perry` |
| Build | `scripts/pmos-build-phosh-release.sh` | `scripts/pmos-build-phase-b.sh` |
| Artifact | `artifacts/pmos-release/pmos-perry-2026-07-21/` | `artifacts/pmos-phase-b/motorola-perry-phosh*.img` |
| Initramfs modules | ~44 (generic msm89x7 panel soup) | ~16 (minimal touch/DRM set) |
| P1.5 fb wait | no (default 10s) | yes (`deviceinfo_framebuffer_wait_seconds=35` + initramfs patch) |
| SSH (live) | `xylitol@172.16.42.1` pw `xylitol` | n/a (no USB) |

Live known-good check (2026-07-22): kernel `7.0.9-msm89x7`,
`CONFIG_HZ=300`, Ofilm panel **loaded from rootfs** (not early initramfs),
DSI-1 720×1280, Wi‑Fi up.

---

## 3. Bisect matrix (hardware)

| ID | Change vs prior Phase B | Image | Result |
|---|---|---|---|
| **A** | Drop `panel_motorola_perry_499v0_ofilm` from `modules-initfs` early load (`device` pkgrel=4) | `motorola-perry-phosh-bisectA.*` | ❌ hang |
| **B** | A + `CONFIG_HZ=300` (was 250); rest of P1 scrub kept (`linux` pkgrel=2) | `motorola-perry-phosh-bisectB.*` | ❌ hang |
| **C** | A + **full** upstream msm89x7 defconfig (undo entire P1.1 scrub; `linux` pkgrel=3) | `motorola-perry-phosh-bisectC.*` | ❌ hang |
| **Rollback** | Known-good release sparse + release NORMAL lk2nd | `pmos-perry-2026-07-21` | ✅ boot + SSH |

### Ruled out as sole cause

1. Early Ofilm panel `modprobe` in initramfs.
2. `CONFIG_HZ=250` (P1.6).
3. Entire P1.1 defconfig scrub (tracers, dynamic debug, panel module pruning, etc.).

### Still in the regression surface

Anything shared by all Phase B images and absent/different on known-good:

1. **`linux-motorola-perry` package** as a whole (build flags, modules install layout, flavor, DT packaging) vs `linux-postmarketos-qcom-msm89x7` + same 0001–0006 patches applied to the generic aport.
2. **`device-motorola-perry`** as a whole (depends, deviceinfo extras, presets, zram 100%, udev rules) vs `device-qcom-msm89x7` + `deviceinfo-motorola-perry`.
3. **P1.5** — `postmarketos-initramfs` framebuffer-wait patch + perry `deviceinfo_framebuffer_wait_seconds=35`.
4. **Minimal `modules-initfs`** (~16 lines) vs generic ~44 — may omit a module needed early (unlikely sole cause after A, but still a delta).
5. **Install recipe** differences (`pmbootstrap install` options, package set).

---

## 4. Next tasks (ordered for “break the phone” sessions)

Do **one variable at a time**. Always keep a known-good sparse ready. Only one
agent holds fastboot. Sacred: never `persist` / `modemst*`.

### T1 — Bisect D: drop P1.5 only (medium effort)

**Hypothesis:** long initramfs fb wait or patched `init_functions.sh` wedging boot.

1. Remove `deviceinfo_framebuffer_wait_seconds` from
   `pmos/device-motorola-perry/deviceinfo` (or set empty).
2. Do **not** apply `scripts/pmos-apply-initramfs-perry.sh` (use unpatched
   upstream `postmarketos-initramfs`).
3. Keep: scrubbed defconfig, modules-initfs without early ofilm, rest of device pkg.
4. Build → flash → pass if USB-net/SSH within ~60s.

### T2 — Kernel-only swap (high value)

**Hypothesis:** `linux-motorola-perry` APKBUILD/build differs from generic
msm89x7 even with the same defconfig/patches.

1. Build known-good overlay image but force install of `linux-motorola-perry`
   (or reverse: Phase B device + generic msm89x7 kernel).
2. Isolates kernel aport vs device aport.

### T3 — Device-only swap

**Hypothesis:** `device-motorola-perry` depends/deviceinfo/presets break boot.

1. `device-qcom-msm89x7` + `deviceinfo-motorola-perry` + `linux-motorola-perry`.
2. Or Phase B device package with generic kernel.

### T4 — modules-initfs parity

Copy known-good `device-qcom-msm89x7` `modules-initfs` (full panel soup)
into `device-motorola-perry`, still without requiring ofilm early if preferred.
Rebuild device pkg only.

### T5 — Overlay control rebuild

Re-run `scripts/pmos-build-phosh-release.sh` (no first-class aports). Flash.
**Must boot** — if not, host/flash path regressed.

### T6 — After a Phase B variant boots

- On-device metrics (plan §5): `systemd-analyze`, `free`, governors, scheduler.
- P1.3 GPU opp baselines ([#3](https://github.com/aneesh-pradhan/xylitol/issues/3)).
- Revisit P1.5 splash confirmation ([#4](https://github.com/aneesh-pradhan/xylitol/issues/4)).
- Park P1.1 scrub / HZ=250 until boot is green; re-introduce one at a time.

### Non-break work (no flash)

- Upstream kernel/panel adoption: [`pmos-upstream-kernel-plan.md`](pmos-upstream-kernel-plan.md) / [#13](https://github.com/aneesh-pradhan/xylitol/issues/13).
- Improve flash tooling (see §5) — already partially done this session.

---

## 5. Tooling notes (this session)

| Change | Why |
|---|---|
| `pmos-flash-phase-b-force.sh`: `RAW`/`SPARSE`/`FORCE`/`NORMAL` env overrides | Flash bisect images without editing script |
| `grep -aFq` for FORCE marker (not `strings \| grep -q`) | `pipefail` + `grep -q` SIGPIPE false-negatives |
| `scripts/pmos-rollback-known-good.sh` | Wait for stock `product: perry`, flash release sparse |
| Competing `fastboot getvar` loops wedge lk2nd | Only one controller; prefer stock Motorola fastboot for reliability |

USB ID cheat sheet:

| ID | Meaning |
|---|---|
| `22b8:2e80` + serial `ZY224TB8KZ` | Stock Motorola fastboot (`product: perry`) |
| `18d1:d00d` + serial `24b071b` | lk2nd fastboot (`product: lk2nd-msm8952`) |
| `18d1:d001` | pmOS USB-net gadget (not fastboot) |

---

## 6. Recovery recipe (known-good)

Device in **stock** fastboot (`product: perry`):

```bash
FORCE=artifacts/pmos-phase-b/lk2nd-force-fastboot.img \
NORMAL=artifacts/pmos-release/pmos-perry-2026-07-21/lk2nd-msm8952-perry.img \
RAW=artifacts/pmos-release/pmos-perry-2026-07-21/qcom-msm89x7-perry-phosh.img.clean \
SPARSE=artifacts/pmos-release/pmos-perry-2026-07-21/qcom-msm89x7-perry-phosh.sparse.clean.img \
  ./scripts/pmos-flash-phase-b-force.sh
```

Or: `./scripts/pmos-rollback-known-good.sh` (waits for stock, then flashes).

SSH: `ssh xylitol@172.16.42.1` (password `xylitol`; host `172.16.42.2/24` on cdc_ncm).

---

## 7. In-repo package state after this write-up

| Package | Intent after docs PR |
|---|---|
| `device-motorola-perry` | pkgrel **4** — ofilm **not** early-loaded in `modules-initfs` (matches known-good early-load policy for ofilm) |
| `linux-motorola-perry` | pkgrel **1** — **scrubbed** defconfig + HZ=250 (product intent; not proven boot-safe until T1–T3 pass) |
| Release path | Untouched; still the daily-driver / recovery image |

Do **not** treat Phase B images as flashable daily-drivers until a bisect variant boots.
