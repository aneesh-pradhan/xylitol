# Reply to agrecascino — POSTED (2026-07-22)

Posted on [linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6#issuecomment-5051820706).
Cross-links also on [kernel#48](https://github.com/msm89x7-mainline/linux/pull/48#issuecomment-5051820877)
and [panel#8](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/8#issuecomment-5051821082).

---

Thanks @agrecascino — appreciated, and no problem picking it up.

For the panels: #8 adds the Ofilm v0 entry alongside your Tianma v1 (same DTB
lineage), so it's meant to supersede this PR — happy to instead land it as a
follow-up commit here if that's cleaner for you. The "only one variant?"
question is settled for at least some units: XT1765 `ZY224TB8KZ` reports
`qcom,mdss_dsi_mot_ofilm_499_720p_video_v0` from lk2nd, and the Ofilm panel has
first-light confirmed on that hardware under postmarketOS.

For the kernel/DTS side (linux#48): I've re-rolled the series against
`msm89x7/7.1.3` addressing @barni2000's review — rpmcc split out (binding +
driver as separate patches, upstream-first), the redundant msm8920.dtsi memory
overrides dropped, GPL-2.0-only relicense, panel pinctrl moved onto `panel@0`
with a single `panel_default` state (matching nora), and the .dts file-mode/
license fixes. Your and Catherine Frederick's authorship + Signed-off-by are
preserved on the carried commits. Fresh PR: msm89x7-mainline/linux#57
(references #48); shout if you'd rather I push onto #48 directly.

---

## Identity — RESOLVED (canonical)
Canonical attribution for ALL of this maintainer's contributions is now, per
project hard rule (CLAUDE.md / AGENTS.md, enforced by `scripts/git-hooks/pre-commit`):

    Aneesh Pradhan <aneeshpradhan@acm.org>

- Kernel re-roll: ✅ author lines preserved (Frederick / Kaechele); committer +
  Signed-off-by + DTS copyright = `aneeshpradhan@acm.org`. Posted as **#57**.
- **PR #8:** ✅ tip commit amended + force-pushed; author/committer/SoB all
  `aneeshpradhan@acm.org`.
