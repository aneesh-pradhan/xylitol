# Future P1+ numbered patches (perf / DT), applied after 0001–0006.
#
# Planned / documented (not all present as files yet):
#   0100 — reserved for cpufreq/OPP DT tweaks after device measurement
#   0101 — reserved for GPU opp / cooling coupling (P1.3)
#
# Done without new patch files (2026-07-21):
#   P1.1 / P1.6 — defconfig scrub + HZ=250 (see config-motorola-perry.aarch64)
#   P1.4 — eMMC mq-deadline via device package udev (not a kernel patch)
#
# P1.2 note (2026-07-21): msm8917.dtsi already provides cpu_opp_table at
# 960 / 1094.4 / 1248 / 1401.6 MHz with cooling-cells; perry enables &gpu.
# Default governor is schedutil (defconfig). No DT patch until on-device
# baselines say otherwise — do not raise opp-hz above stock.
#
# Boot-hang bisection (2026-07-21 → 2026-07-22):
#   A/B/C all FAIL on hardware. Device recovered on known-good overlay.
#   Canonical write-up + next isolation (T1–T6):
#     docs/phase-b-boot-hang-bisect.md
#   A: ofilm out of modules-initfs — not sole cause
#   B: HZ=300 — not sole cause
#   C: full upstream defconfig — not sole cause
#   Live defconfig restored to scrubbed HZ=250 (product intent; unvalidated).
