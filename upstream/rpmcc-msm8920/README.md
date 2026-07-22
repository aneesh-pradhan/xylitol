# Step A — `qcom,rpmcc-msm8920` (upstream-first)

**Track:** [xylitol#13](https://github.com/aneesh-pradhan/xylitol/issues/13) ·
[`docs/pmos-upstream-kernel-plan.md`](../../docs/pmos-upstream-kernel-plan.md)  
**Date:** 2026-07-22  
**Status:** Patch drafted against **torvalds/linux master** (fetched 2026-07-22).
Not yet mailed. Applies cleanly (`git apply --check`).

## Why this is step A

`drivers/clk/qcom/clk-smd-rpm.c` and
`Documentation/devicetree/bindings/clock/qcom,rpmcc.yaml` are **shared
mainline files**. msm89x7-mainline CONTRIBUTING requires them upstream
before (or at least before claiming) fork merge of the fuller MSM8920 +
perry series ([linux#48](https://github.com/msm89x7-mainline/linux/pull/48)).

## What the patch does

File: [`0001-clk-qcom-smd-rpm-add-support-for-MSM8920.patch`](0001-clk-qcom-smd-rpm-add-support-for-MSM8920.patch)

| File | Change |
|---|---|
| `drivers/clk/qcom/clk-smd-rpm.c` | Add `msm8920_clks[]` + `rpm_clk_msm8920` + OF match `qcom,rpmcc-msm8920` |
| `qcom,rpmcc.yaml` | Add compatible to top-level enum + pxo/cxo `allOf` group |

**Clock table design** (verified against current mainline tables):

| SoC | BIMC_GPU | IPA | Notes |
|---|---|---|---|
| MSM8917 | yes | no | base |
| MSM8940 | no | yes | larger modem / IPA class |
| **MSM8920 (this patch)** | **yes** | **yes** | 8917 set **+** IPA (from 8940) |

So MSM8920 is exactly **MSM8917 + `RPM_SMD_IPA_{,A_}CLK`**. No new IDs in
`include/dt-bindings/clock/qcom,rpmcc.h` (IPA IDs already present).

This matches `msm8920.dtsi` intent from the fork series: `rpmcc` compatible
`qcom,rpmcc-msm8920` and IPA node clock `<&rpmcc RPM_SMD_IPA_CLK>`.

## Diff vs the old fork mega-commit

The rpmcc hunk in xylitol `pmos/.../0002-arm64-qcom-add-support-for-MSM8920.patch`
(and PR #48 `ceace8c`) is the same *idea* but:

- Was mixed with `msm8920.dtsi` (must stay out of this series).
- Was generated against an older fork yaml context; **this patch is rebased
  on torvalds/linux master** as of 2026-07-22.
- Style matches mainline tab alignment (`[RPM_…]\t\t= &…`).

## Maintainer / submit path

From mainline `MAINTAINERS` (**QUALCOMM CLOCK DRIVERS**):

- **M:** Bjorn Andersson `<andersson@kernel.org>`
- **L:** `linux-arm-msm@vger.kernel.org`
- **T:** `git://git.kernel.org/pub/scm/linux/kernel/git/qcom/linux.git`
- **F:** `drivers/clk/qcom/`, `Documentation/devicetree/bindings/clock/qcom,*`

### Suggested send (when ready)

```bash
# Refresh against latest qcom/linux or torvalds master, re-generate if needed
git send-email \
  --to 'Bjorn Andersson <andersson@kernel.org>' \
  --cc 'linux-arm-msm@vger.kernel.org' \
  --cc 'devicetree@vger.kernel.org' \
  --cc 'linux-clk@vger.kernel.org' \
  upstream/rpmcc-msm8920/0001-clk-qcom-smd-rpm-add-support-for-MSM8920.patch
```

Optional: also CC Catherine Frederick (coolguy) for prior art credit on the
fork series; keep their SoB only if carrying their commit unmodified —
this re-roll is authored by us with a single SoB.

### Local smoke (optional)

```bash
# From a full kernel tree at the same base as the patch:
git am /path/to/0001-clk-qcom-smd-rpm-add-support-for-MSM8920.patch
# dt_binding_check if dt-schema installed:
make dt_binding_check DT_SCHEMA_FILES=Documentation/devicetree/bindings/clock/qcom,rpmcc.yaml
```

## Relationship to later steps

- **Step B** (`msm8920.dtsi`) depends on this compatible existing (or can
  land in the same series as a second patch *after* clk, still aimed at
  mainline).
- **Step C** (perry DTS) stays on msm89x7-mainline until A/B are upstream
  or at least submitted.
- **xylitol runtime** continues to carry rpmcc via local `0002` until a
  packaged kernel picks this up; no need to change Phase B images for A.

## Explicit non-claims

- Not hardware-tested as a *standalone* mainline boot (perry still uses
  the msm89x7 fork package + local patches). The IPA clock requirement is
  justified by the DTS/IPA integration already present in the fork series
  and by analogy to MSM8940's rpmcc table.
- MSS/IPA *node* correctness in `msm8920.dtsi` remains a **step B** review
  item (`barni2000`: “8940 MSS good for 8920?”) — out of scope for this
  clk-only patch.
