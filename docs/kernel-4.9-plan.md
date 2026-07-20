# Side quest plan: perry on the staging-4.9 kernel

**Status: PARKED.** Do not start until 18.1 hardware bring-up is done
(camera + RIL at minimum — handoff P1/P2). Recon and fact-check that
produced this plan: `porting-log.md` 2026-07-20 entry.

## Goal

Boot our existing LineageOS 18.1 userspace on a 4.9 kernel built from
`moto-msm89xx/android_kernel_motorola_msm8953` branch
`staging/lineage-18.1` (CAF msm-4.9.227), by porting perry's Motorola
kernel layer (DTS + a few drivers + defconfig) from our 3.18 tree.
Stretch payoff: unlocks a credible lineage-19.1/20 conversation later
(xiaomi msm8937 precedent) and 4.9 LTS security fixes.

## Reference trees (clone these before starting)

| Tree | Why |
| :--- | :--- |
| `moto-msm89xx/android_kernel_motorola_msm8953` @ `staging/lineage-18.1` | The porting target: CAF 4.9.227 + prima + techpack/audio + sdfat |
| our `kernel/motorola/msm8953` @ `lineage-18.1` (3.18.140) | Source of truth for perry DTS chain, Moto drivers, `perry_defconfig` |
| `klabit87/android_kernel_motorola_surfna` @ `surfna_9` (4.9.112) | Motorola's own 4.9 for QM215/SDM429: the 3.18→4.9 Rosetta stone for `utag`, `mmi_*`, `dsi-panel-mot-*`, Moto DTS bindings |
| `LineageOS/android_kernel_xiaomi_msm8937` @ `lineage-20` (4.9.337) | Official LOS production 4.9 on this SoC: kernel-config authority (eBPF, cgroups, etc.) and later the LTS-merge + 19.1/20 template |
| `samsung-msm8917/android_kernel_samsung_msm8917` @ `lineage-18.1` (3.18.124) | Sanity cross-check only: another A11-on-3.18 tree |
| ACK `android-4.9-q` (android.googlesource.com/kernel/common) | Diff source if any Android-required feature turns out missing from CAF 4.9.227 (expected: none or trivial) |

## Phase 0 — Study (no build, no device)

1. `git fetch` staging branch into the local kernel clone (full history
   is already configured for this repo in the manifest).
2. Identify the CAF base tag (`git describe`, merge topology) — expect
   LA.UM.8.x/9.x era. Note it in the log.
3. Confirm-or-refute the Gemini-doc topics against the actual tree
   (expected state in parentheses): eBPF configs available (yes — enable
   in defconfig), memfd (in-kernel since 3.17), binderfs (optional;
   present or irrelevant), fscrypt v1+ICE (present — matches common
   fstab), sdcardfs (present), cgroup freezer v1 (present).
4. Diff `msm8937go-perf_defconfig` (staging) vs our 3.18
   `perry_defconfig` vs xiaomi lineage-20 defconfig → draft the option
   list for a 4.9 `perry_defconfig`.
5. Map every node in perry's DTS chain to its staging-4.9 equivalent,
   using surfna to translate binding changes. Deliverable: a checklist
   of nodes with port difficulty (copy / adapt / rewrite).
6. Resolve the open sensor question: are bma253/ak09911/epl8802/sx9310
   kernel drivers or ADSP-side config on 8917? (Check 3.18 defconfig
   for their drivers and surfna's handling.)

## Phase 1 — Kernel port (build only)

1. Port DTS chain (~1.7–2k lines): `msm8917-perry-p0.dts`,
   `msm8917-perry.dtsi`, `msm8917-perry-common.dtsi`,
   `msm8917-moto-common.dtsi`, `msm8917-camera-sensor-mot-perry.dtsi`,
   tianma/ofilm-499 panel dtsis, gk40 batterydata.
2. Port Moto drivers: `drivers/misc/utag`, et320 fingerprint,
   `mmi,alsa-to-h2w`, `mmi,sys-temp`; decide Moto `synaptics_dsx_i2c`
   vs staging's CAF dsx (surfna shows Moto's 4.9 choice).
3. Create `perry_defconfig` (arm64) from the Phase 0 diff.
4. Standalone kernel build (Image.gz + dtb, appended-DTB layout like
   3.18 — perry has no dtbo partition).
5. Record everything as `patches/kernel-4.9/...` series, `git am`-
   verified, same convention as the existing series.

## Phase 2 — First boot (reversible experiments only)

Safety: `fastboot boot` ONLY — no flashing until Phase 3 is green.
persist/modemst are never touched by any of this; abort anything that
would.

1. Repack current 18.1 boot.img with the 4.9 kernel+dtb; add
   `androidboot.selinux=permissive` for first boots only.
2. Milestone ladder: splash → panel lights up (mdss/panel DTS right) →
   touch (dsx) → adb over configfs → `dmesg` triage.
3. Userspace variant build for 4.9: drop/revert our staging-4.9-revert
   patches on a branch — msm8937-common 0004 (back to FBE `ice`;
   requires a /data format between kernels), 0005 (4.9 vold paths),
   0006 (keep eBPF prop), kernel 0002 (uapi shim unneeded), perry 0009
   (VINTF enforce back on). Keep the 3.18 series intact — the two
   kernels need parallel patch series, not a fork of one.
4. Iterate to `sys.boot_completed=1`, then selinux back to enforcing
   and collect denials (expect bpf/binderfs-adjacent additions).

## Phase 3 — Subsystem re-bring-up (ordered by risk, low → high)

1. **Wi-Fi** (prima in staging; mirrors our kernel 0003 setup) — low.
2. **Display/GPU** under load (Nougat Adreno 308 blobs vs 4.9 KGSL);
   fallback: QM215 Pie-era A308 blobs — medium.
3. **Audio** (techpack DAI/mixer-path renames) — medium.
4. **RIL/data** (Nougat netmgrd vs 4.9 rmnet_data) — medium; GSM-only.
5. **Sensors** (per Phase 0 finding) — medium.
6. **Camera** — worst; expect Nougat mm-qcamera daemon to fail against
   4.9 msm_camera ioctls. Fallback path: QM215/SDM429 Pie camera stack
   + hunt Pie-era imx219/s5k4h8/ov5695 sensor libs from other QM215
   devices. Budget this as its own project; do not let it block
   declaring Phases 0–2 a success.

## Phase 4 — Decision point

- If stable through RIL: merge 4.9 LTS 227→337 (mechanical, xiaomi tree
  as reference), decide 3.18 vs 4.9 as the primary 18.1 kernel, and
  only then open the lineage-19.1/20 question (xiaomi msm8937 is the
  template; 32-bit blob constraint still caps us below A14).
- If blob-ABI losses (camera/RIL) outweigh gains: keep 4.9 as a build-
  verified curiosity branch, stay on 3.18, log the autopsy.

## Ground rules

- 3.18 remains the shipping kernel throughout; nothing here may
  destabilize the 18.1 bring-up work or its patch series.
- Every phase produces a porting-log entry; every tree change lands as
  a `git am`-verified patch series in `patches/`.
- The Gemini doc (`~/Downloads/gemini-code-1784568301149.md`) is a
  topic checklist only — its commit lists/citations are unreliable
  (fact-check: porting-log 2026-07-20). Trust the xiaomi/surfna trees.
