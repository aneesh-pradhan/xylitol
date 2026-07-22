# Perry / MSM8920 re-roll — review-response (DRAFT)

Re-rolled against fork branch **`msm89x7/7.1.3`** (current; PR #48 targets the
older `msm89x7/6.19.5`). Base commit `50f9719`. Four commits, checkpatch-clean.
Original authorship (**Catherine Frederick**, kept as the From: author) +
Signed-off-by preserved; this maintainer is added additively as a bracketed
`[aneesh: …]` change-note + Signed-off-by, per DCO / kernel carry-and-modify
convention.

**Attribution (project hard rule):** committer, `Signed-off-by`, and the DTS
`Copyright` lines all use **`Aneesh Pradhan <aneeshpradhan@acm.org>`** — the only
acceptable identity (enforced by `scripts/git-hooks/pre-commit`). Frederick
remains the primary author; we are only adding to her work.

## Series structure (addresses barni2000's "split rpmcc" + "proper descriptions + SoB")

| # | Commit | Files |
|---|---|---|
| 0001 | dt-bindings: clock: qcom,rpmcc: add MSM8920 | `qcom,rpmcc.yaml` |
| 0002 | clk: qcom: smd-rpm: add MSM8920 support | `clk-smd-rpm.c` |
| 0003 | arm64: dts: qcom: add MSM8920 device tree | `msm8920.dtsi` |
| 0004 | arm64: dts: qcom: add Motorola Moto E4 (perry) | perry-common.dtsi + 2× .dts + Makefile |

- rpmcc (0001+0002) is split out of the SoC dtsi and further split binding-from-driver
  (checkpatch: "DT binding docs … should be a separate patch"). These two are the
  upstream-first pieces (linux-arm-msm) — same content staged in `upstream/rpmcc-msm8920/`.
- Kaechele's `Input: rmi_i2c` reset commit is carried **unchanged** (already clean SoB,
  no review issues) — not re-rolled here.

## Every review comment → resolution

### Top-level (barni2000)
- **"Remove the panel commit, open PR in linux-panel-drivers"** → already done; panels
  are in PR #6/#8, not in this series. Not regressed.
- **"Add proper descriptions and your SoB"** → all four commits now have full descriptions
  + preserved original SoB + our SoB.

### msm8920.dtsi (commit 0003)
- **line 60 / 73 — redundant memory overrides ("override only where necessary" /
  "useless, exactly same in msm8917.dtsi")** → **all 5 removed.** Evidence: adsp/gps/mba/
  venus/wcnss sizes are byte-identical to `msm8917.dtsi` on the 7.1.3 base, AND the
  in-tree `msm8940.dtsi` (same IPA sibling) overrides none of them.
- **line 77 — "Are you sure 8940 MSS is good for 8920?"** → **the IPA block is byte-for-byte
  identical to the in-tree, already-reviewed `msm8940.dtsi`** (ipa@7900000: reg, IRQs 228/230,
  ctx 0x18, modem-remoteproc, disabled; plus the matching `apps_iommu` NS context @18000).
  The IPA-lite v2.6 IP is common across the msm89xx family at the same 0x7900000 base.
  Note: unlike 8940 (which sets `gcc-msm8940` + `msm8940-mss-pil` vs its 8937 base), 8920
  inherits 8917's gcc/mss-pil — correct, since **no `gcc-msm8920` exists** and there is no
  evidence of a distinct 8920 mss-pil. Modem itself is unused/untested on perry (no usable
  bands); IPA stays `disabled` by default. Honest open item flagged rather than asserted.
- **line 1 — license** → `BSD-3-Clause` → **`GPL-2.0-only`** (matches included `msm8917.dtsi`).
- **line 3 — copyright** → added `Copyright (c) 2026, Aneesh Pradhan` additively (Dang Huynh kept).

### perry-common.dtsi (commit 0004)
- **line 194-196 / 438 / 446 — pinctrl placement + panel_default rename + "Remove"** →
  matched the in-tree sibling **nora** exactly: moved `pinctrl-0`/`pinctrl-names` onto the
  `panel@0` node (removed from `&mdss_dsi0`), renamed state `mdss_dsi_default` →
  `panel_default`, **dropped the sleep state** (the panel driver owns the reset GPIO).
- **line 201 — "only 1 panel variant?"** → keep Tianma as the pragmatic upstream default;
  the Ofilm variant is noted in the commit + handled in panel PR #8. (On-glass Ofilm
  first-light confirmed on XT1765 `ZY224TB8KZ`.)
- **line 230 — "8917 not need this" (pm8937_s5 / VDD_APC)** → **KEEP; pushing back.**
  Counter-evidence: the in-tree **nora** (also MSM8917) ships the identical `pm8937_s5`
  with the same "PM8937 S5 + S6 = VDD_APC supply" comment. VDD_APC is the CPU core rail.
- **line 521 — wcn3660b "link relevant part from msm8952.c"** → `qcom,wcn3660b` matches the
  in-tree **msm8937 montana** (same-era Motorola). Downstream IDs the iris variant at
  runtime (no DT compatible string to grep), so there is no literal `msm8952.c` line; the
  mainline `qcom,wcn3660b` is the correct abstraction, **board-validated** (Wi-Fi associates
  on perry — confirmed on the 7.1.3 boot, 2026-07-22). Will state this in the reply rather
  than fabricate a citation.

### perry .dts files (commit 0004)
- **line 1 — license** → both `BSD-3-Clause` → **`GPL-2.0-only`**.
- **line 3 — copyright** → added ours additively (Val Packett kept).
- **file mode** → both `100755` → **`100644`**.

## Compliance with fork CONTRIBUTING.md (source of truth)

Checked against `CONTRIBUTING.md` @ base `50f9719` (the msm8916-mainline/linux
policy; the fork is titled msm8916 internally but same repo/policy):

| Requirement | Status |
|---|---|
| No compile warnings/errors | checkpatch-clean; full build + `dtbs_check` = pre-post step |
| Clean code style | ✅ (Makefile tab normalised, GPL-2.0 headers, pinctrl per nora) |
| One logical change / subsystem per commit | ✅ binding / driver / SoC dtsi / device dts = 4 commits |
| Commit message explains motivation | ✅ full descriptions on all four |
| Signed-off-by (DCO) | ✅ Frederick's preserved + ours added; DCO's own "someone else can pick up your work" rationale is exactly this pickup |
| Shared upstream files submitted upstream first | ✅ rpmcc (`clk-smd-rpm.c` + `qcom,rpmcc.yaml`) split to 0001+0002 for linux-arm-msm |

## Posted (2026-07-22)

- Fresh PR: **[msm89x7-mainline/linux#57](https://github.com/msm89x7-mainline/linux/pull/57)**
  (base `msm89x7/7.1.3`, includes rmi_i2c + this 4-patch re-roll).
- Supersedes #48 (comment left on #48).
- **`dtbs_check` / DTB build**: both perry DTBs build clean; `dtbs_check`
  warning count/class matches in-tree **nora** (shared SoC/schema gaps — not
  new perry regressions). `dt-doc-validate` on rpmcc yaml clean.

## Still open / judgment calls for the maintainer
1. **Target branch**: re-rolled on `msm89x7/7.1.3` (current) vs PR #48's `6.19.5` — #57 uses 7.1.3.
2. **Fresh PR vs push to #48**: chose fresh **#57**; offered to force-push onto #48 if preferred.
3. **rpmcc upstream mail (Step A)**: 0001+0002 are the upstream-first pieces; sending them to
   linux-arm-msm is **still parked** per the project hold — do not `git send-email` until asked.
4. Optional follow-up: document `motorola,perry` / `qcom,msm8920` in `arm/qcom.yaml`
   (in-tree nora is also undocumented there today).
