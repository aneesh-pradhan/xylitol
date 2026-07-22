# linux-motorola-perry — custom perry kernel aport

Canonical **device-tree + panel + defconfig** home for the XT1765 / MSM8917
mainline port. Upstream tarball is `msm89x7-mainline/linux` (`v7.0.9-r0`);
perry-specific work lives here as patches + config.

See [`../../docs/perry-custom-kernel-plan.md`](../../docs/perry-custom-kernel-plan.md).

## Layout

| Path | Role |
|---|---|
| `APKBUILD` | aport (`pkgver=7.0.9`, flavor `motorola-perry`) |
| `config-motorola-perry.aarch64` | tracked defconfig (**P1.1/P1.6 scrubbed**; Alpine clang markers kept) |
| `patches/0001–0006` | perry DTS, MSM8920 bits, RMI reset, Tianma + **Ofilm** panels |

P1 status: scrub + HZ=250 done; cpufreq OPP audited (no DT patch yet).
Future: `patches/01xx-*.patch` (GPU opp/cooling after measurement).

## Patch index (device tree / panels)

| Patch | What |
|---|---|
| 0001 | `rmi_i2c` reset GPIO |
| 0002 | MSM8920 SoC bits (family) |
| 0003 | **perry DTS** `msm8917-motorola-perry` |
| 0004 | Tianma 499v1 panel driver |
| 0005 | **Ofilm 499v0** panel driver (this XT1765) |
| 0006 | DTS: select Ofilm 499v0 |

These are the single source of truth. The legacy
`../linux-postmarketos-qcom-msm89x7/` overlay apply script copies **from**
`patches/` so the published `qcom-msm89x7` path stays in sync.

## Build (host pmaports only — no flash)

```bash
./scripts/pmos-apply-kernel-perry.sh
pmbootstrap checksum linux-motorola-perry
pmbootstrap build    linux-motorola-perry
```

Archived pmaports conflict: apply script removes local
`device/archived/linux-motorola-perry` (stale 3.18 fork, same pkgname).

**Hardware:** Phase B images **hang** on XT1765 (2026-07-21 bisect A/B/C
all failed). Use known-good overlay release for a working phone. Isolation
queue: [`docs/phase-b-boot-hang-bisect.md`](../../docs/phase-b-boot-hang-bisect.md).
`scripts/pmos-build-phase-b.sh` only when deliberately bisecting.
