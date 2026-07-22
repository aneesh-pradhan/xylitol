# Phase B boot-hang bisect (2026-07-21 → 2026-07-22)

**Status:** Hang **root-caused** — **P1.5** (initramfs framebuffer-wait patch +
`deviceinfo_framebuffer_wait_seconds=35`). **Bisect D PASS** (SSH + Ofilm DRM).
First-class `device-motorola-perry` + `linux-motorola-perry` boots when P1.5 is
absent. Default Phase B build should **not** apply P1.5 until a safe splash
fix is re-designed.

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

| | **Known-good overlay** | **Phase B + P1.5 (hangs)** | **Phase B Bisect D (boots)** |
|---|---|---|---|
| Device | `device-qcom-msm89x7` + `deviceinfo-motorola-perry` | `device-motorola-perry` | same, **no** `framebuffer_wait_seconds` |
| Kernel | `linux-postmarketos-qcom-msm89x7` | `linux-motorola-perry` | `linux-motorola-perry` **7.0.9-r1** (scrubbed, HZ=250) |
| Build | `scripts/pmos-build-phosh-release.sh` | `pmos-build-phase-b.sh` (P1.5 on) | `DROP_P15=1 pmos-build-phase-b.sh` |
| Initramfs | stock wait (~10s) | **patched** wait knob + 35s | **unpatched** `postmarketos-initramfs` **3.12.0-r0** |
| SSH | yes | no (hang) | **yes** (~25s after continue) |

Live Bisect D check (2026-07-22): kernel `7.0.9-msm89x7` **#2-perry-xylitol**,
`CONFIG_HZ=250`, Ofilm panel loaded, DSI-1 720×1280, USB-net + SSH.

---

## 3. Bisect matrix (hardware)

| ID | Change vs prior Phase B | Image | Result |
|---|---|---|---|
| **A** | Drop `panel_motorola_perry_499v0_ofilm` from `modules-initfs` early load (`device` pkgrel=4) | `motorola-perry-phosh-bisectA.*` | ❌ hang |
| **B** | A + `CONFIG_HZ=300` (was 250); rest of P1 scrub kept (`linux` pkgrel=2) | `motorola-perry-phosh-bisectB.*` | ❌ hang |
| **C** | A + **full** upstream msm89x7 defconfig (undo entire P1.1 scrub; `linux` pkgrel=3) | `motorola-perry-phosh-bisectC.*` | ❌ hang |
| **D** | A + **drop P1.5 only** (unpatched initramfs r0; no `deviceinfo_framebuffer_wait_seconds`; scrubbed HZ=250 kernel r1) | `motorola-perry-phosh-bisectD.*` | ✅ **boot + SSH** (~25s) |
| **Rollback** | Known-good release sparse + release NORMAL lk2nd | `pmos-perry-2026-07-21` | ✅ boot + SSH |

### Ruled out as sole cause

1. Early Ofilm panel `modprobe` in initramfs.
2. `CONFIG_HZ=250` (P1.6) — **present on the green Bisect D boot**.
3. Entire P1.1 defconfig scrub — scrubbed kernel boots on D.
4. First-class `linux-motorola-perry` / `device-motorola-perry` packages as a
   set (they boot once P1.5 is removed).

### Root cause (confirmed by D)

**P1.5** — `pmos/postmarketos-initramfs/0001-make-framebuffer-wait-timeout-device-configurable.patch`
plus perry `deviceinfo_framebuffer_wait_seconds="35"`. With that combo, boot
stalls: backlight on, black screen, **no USB**. Without it, first-class path
reaches userspace (USB-net + SSH, Ofilm DRM 720×1280).

Mechanism still open (busy-wait starving gadget? patch bug? interaction with
perry DRM bind timing?) — do **not** re-enable until understood. Splash gap
is cosmetic; hang is not.

Evidence: `artifacts/pmos-phase-b/evidence-bisectD-boot/`,
`artifacts/pmos-phase-b/flash-bisectD.log`, `auto-bisect.result`.

---

## 4. Next tasks (post–Bisect D)

Hang isolation queue **closed**. Prefer non-destructive / product work:

### T1 — ~~Bisect D~~ ✅ DONE (2026-07-22)

### T6 — On-device metrics + P1.3 (unblocked)

Device is on first-class Phase B (Bisect D image). Safe over SSH:

- `systemd-analyze`, `free`, governors, eMMC scheduler (plan §5).
- P1.3 GPU opp baselines ([#3](https://github.com/aneesh-pradhan/xylitol/issues/3)).
- User visual: Phosh greeter / soft navbar / any splash gap (expected without P1.5).

### P1.5 follow-up / redesign sketch (do not flash a re-enable blindly)

- Keep patch in-tree for research; **default build must not apply it**.
- Hypotheses for the hang (unproven): long busy-wait before USB gadget setup;
  patch interaction with perry DRM bind; starvation in initramfs poll loop.
- **Safe redesign directions** (pick one, single-variable test, recovery staged):
  1. **No splash on perry** — accept ~27s black until DRM binds (current default).
  2. **Wait after gadget** — ensure USB/network path is up before any fb wait.
  3. **Non-blocking / short poll** — e.g. cap wait ≤10s with sleep yielding, never 35s.
  4. **Patched initramfs, default 10 only** — no deviceinfo override; isolate “patch
     present” vs “35s duration” if ever re-tested.
- Optional single-variable re-test later — **only** with known-good sparse ready
  and stock fastboot recovery rehearsed ([#4](https://github.com/aneesh-pradhan/xylitol/issues/4)).

### T2–T5 — deprioritized

No longer required for hang isolation. Revisit only if a new regression
appears when re-introducing splash work.

### Non-break work (no flash)

- Upstream kernel/panel adoption: [`pmos-upstream-kernel-plan.md`](pmos-upstream-kernel-plan.md) / [#13](https://github.com/aneesh-pradhan/xylitol/issues/13).

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

## 7. In-repo package state after Bisect D

| Package | Intent |
|---|---|
| `device-motorola-perry` | pkgrel **4** — ofilm **not** early-loaded; **no** `deviceinfo_framebuffer_wait_seconds` (P1.5 off) |
| `linux-motorola-perry` | pkgrel **1** — scrubbed defconfig + HZ=250 — **hardware-validated** on Bisect D |
| `postmarketos-initramfs` | Default Phase B: **unpatched** upstream (do not apply P1.5 patch) |
| Release path | Untouched overlay daily-driver / recovery: `pmos-perry-2026-07-21` |

First-class Phase B **boots** without P1.5. Prefer staging a non-P1.5 product
image before treating it as daily-driver; keep rollback sparse ready.
