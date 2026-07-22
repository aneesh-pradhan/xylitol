# Perry / MSM8920 upstream kernel + panel adoption plan

**Date opened:** 2026-07-21. **Tracking issue:** [xylitol#13](https://github.com/aneesh-pradhan/xylitol/issues/13).
**Track:** postmarketOS mainline kernel, upstream contribution work.
**Status (2026-07-22):** **In progress.** Step D (panels) started:
[linux-panel-drivers#8](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/8)
(Tianma + Ofilm; supersedes #6). Courtesy adoption comment posted on
[linux#48](https://github.com/msm89x7-mainline/linux/pull/48). Steps A–C
(rpmcc → msm8920.dtsi → perry DTS re-roll) still open. Pure research +
patch-writing — **no flash required** for the next kernel steps.

---

## 0. One-paragraph situation (read this first)

perry (Moto E4, XT1765, MSM8917) boots postmarketOS today, but only because
xylitol carries **local, un-upstreamed patches** on top of the packaged
`linux-postmarketos-qcom-msm89x7` kernel (`pmos/linux-postmarketos-qcom-msm89x7/0001-0006`,
mirrored into our first-class `pmos/linux-motorola-perry/patches/`). Those
patches are themselves a rebase of a **stalled draft PR**,
[msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48),
opened 2026-04-18, marked `CHANGES_REQUESTED` by the fork's maintainer
(`barni2000`), with the original author (`agrecascino`, actual DTS work by
co-author `coolguy`/Catherine Frederick) never having responded to the
review. The fork's own `CONTRIBUTING.md` says work like this is fair game to
pick up under DCO (Developer's Certificate of Origin — the `Signed-off-by`
system) specifically *because* authors go quiet. This plan is that pickup:
turn PR #48 (kernel DTS + rpmcc) and its companion panel PR
[linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6)
(Tianma panel only — missing our unit's actual **Ofilm** panel) into clean,
mergeable, eventually-upstream-submittable patch series. The payoff: once a
tagged `linux-postmarketos-qcom-msm89x7` release ships perry's DTB natively,
xylitol's local kernel overlay shrinks to nothing (or close to it) and we
stop carrying a private DTS fork forever.

**This is squarely a research + kernel-patch-writing task.** You will spend
your time reading DTS/C, comparing against sibling devices, writing commits,
and opening PRs against `msm89x7-mainline` repos — not touching the xylitol
repo's runtime behavior, not building images, not flashing anything. If you
find yourself about to run `pmbootstrap`, `fastboot`, or edit anything under
`pmos/device-motorola-perry/` or `pmos/linux-motorola-perry/`, stop — that's
a different track (see [`perry-custom-kernel-plan.md`](perry-custom-kernel-plan.md)).

---

## 1. Why this matters (motivation, not busywork)

- **Maintenance burden today:** xylitol carries perry's entire DTS + panel
  drivers as local patches against a kernel package we don't control the
  release cadence of. Every `linux-postmarketos-qcom-msm89x7` bump risks a
  patch-conflict rebase.
- **Maintainer gate is explicit and specific**, not vague "please clean up
  someday." `barni2000`'s stated position on #48: *separate rpmcc, send
  upstream; send initial 8920 + perry upstream; will wait to merge until
  then.* This is a real, actionable bar — not a moving target.
- **We have evidence the original PR lacks:** our local carry (0001-0006)
  has actually **booted this exact hardware** with the Ofilm panel
  confirmed on-glass (2026-07-20, see `docs/pmos-ofilm-panel.md` and
  porting-log). PR #48 and panel PR #6 were written and reviewed without
  that confirmation — the panel PR's own thread has the author saying they
  "never seen a qualcomm perry with anything other than the tianma," which
  we now know is wrong for at least this unit (XT1765 `ZY224TB8KZ`).
- **DCO makes this legitimate, not presumptuous.** The fork's
  `CONTRIBUTING.md` (https://github.com/msm89x7-mainline/linux/blob/msm89x7/7.1.3/CONTRIBUTING.md,
  still titled "msm8916" internally, same repo/policy) exists precisely so
  that abandoned work can be picked up by someone else, provided the new
  submitter properly signs off and doesn't misrepresent authorship. Original
  commits keep their original `Signed-off-by`; anything **we** author or
  materially rewrite gets **our own** `Signed-off-by` added.

---

## 2. Verified facts (do not re-litigate — re-fetch only if something looks stale)

All fetched live via `gh` on 2026-07-21. If any of this looks wrong when you
pick this up, the world may have moved — re-verify with the same commands
before trusting old numbers (this document, like the codebase, decays).

### 2.1 PR #48 (`msm89x7-mainline/linux`) — the kernel/DTS series

```bash
gh pr view 48 --repo msm89x7-mainline/linux --json title,state,body,author,createdAt,files,commits,comments
gh api repos/msm89x7-mainline/linux/pulls/48/reviews
gh api repos/msm89x7-mainline/linux/pulls/48/comments   # line-level review comments
gh pr diff 48 --repo msm89x7-mainline/linux              # full diff, 847 lines as of 2026-07-21
```

- **Author:** `agrecascino` (opened it; body is a one-line joke, no
  description). Actual DTS/rpmcc authorship: **Catherine Frederick
  ("coolguy")** `<serenity@floorchan.org>`, per commit `Signed-off-by`.
  Touchscreen-reset commit authored by **Felix Kaechele**
  `<felix@kaechele.ca>` (already has a proper SoB — do not touch that
  commit's authorship, it's clean, just needs the panel-commit removed from
  the same PR per review comment below).
- **State:** OPEN, review state `CHANGES_REQUESTED` by `barni2000`
  (COLLABORATOR), submitted 2026-04-18T12:05:32Z (empty review body — all
  feedback is in line comments, listed in full in §4 below).
- **3 commits:**
  1. `d3dc233` — `Input: rmi_i2c: introduce reset GPIO handling` (Kaechele,
     clean SoB, tested on Moto G5 Plus/Potter). **Already correctly carried**
     as our local `pmos/linux-motorola-perry/patches/0001-*`.
  2. `ceace8c` — `arm64: qcom: add support for MSM8920` (Frederick, no SoB
     issue but needs review fixes, see §4.2). Carried as our `0002-*`.
  3. `b87b04a` — `arm64: dts: qcom: add support for motorola-perry`
     (Frederick). Carried as our `0003-*` **with the Makefile typo already
     fixed locally** (`dtb-$(CONFIG_ARCH_QCOM  += msm8917-motorola-perry.dtb`
     — missing closing paren in the upstream PR, confirmed by direct diff
     inspection at line matching `arch/arm64/boot/dts/qcom/Makefile`).
- **10 files touched:** `Documentation/devicetree/bindings/clock/qcom,rpmcc.yaml`,
  `arch/arm64/boot/dts/qcom/Makefile`,
  `arch/arm64/boot/dts/qcom/msm8917-motorola-perry-common.dtsi` (new, 533
  lines), `msm8917-motorola-perry.dts` (new, 32 lines),
  `msm8920-motorola-perry.dts` (new, 28 lines), `msm8920.dtsi` (new, 55
  lines), `drivers/clk/qcom/clk-smd-rpm.c` (+31), plus the 3 rmi4 driver
  files for the touchscreen-reset commit.
- **barni2000's two top-level comments** (not line comments):
  1. *"Please remove the panel commit and open PR here
     https://github.com/msm89x7-mainline/linux-panel-drivers/pulls"* — i.e.
     this PR should be kernel/DTS only; panels belong in the separate
     `linux-panel-drivers` repo. (This was already followed — panel PR #6
     exists separately. Just confirming the split is correct and should
     stay that way for our re-roll too.)
  2. *"Add proper descriptions and your SoB for your commits"* — the MSM8920
     and perry-DTS commits currently have one-line headlines and no body
     explaining the change; needs real commit messages.

### 2.2 Panel PR #6 (`msm89x7-mainline/linux-panel-drivers`) — Tianma only

```bash
gh pr view 6 --repo msm89x7-mainline/linux-panel-drivers --json title,state,body,files,commits
gh api repos/msm89x7-mainline/linux-panel-drivers/pulls/6/comments
gh pr diff 6 --repo msm89x7-mainline/linux-panel-drivers
```

- **State:** OPEN, no formal review state, but has an unresolved line
  comment thread.
- **2 files:** `config/motorola-perry.sh` (new, 6 lines) and
  `dtb/motorola-perry.dtb` (binary — a reference DTB the panel-driver
  generator (`lmdpdg`) uses to extract panel init sequences).
- **Current `config/motorola-perry.sh` content:**
  ```bash
  #!/usr/bin/env bash

  OPTIONS=()
  PANELS=(
  	[tianma_499_720p_video_v1]="motorola,perry-499v1-tianma"
  )
  ```
- **The key exchange** (this is the evidence gap we now have that upstream
  didn't, when this was reviewed):
  - `barni2000` (review comment on `config/motorola-perry.sh:5`): *"Do this
    device have only one panel variant?"*
  - `agrecascino` (reply): *"Pretty sure. Woods has BV050HDM, but I've never
    seen a qualcomm perry with anything other than the tianma, and I don't
    think panel driver generator noticed anything either."*
  - **We know this is wrong for at least one real unit.** This XT1765
    (`ZY224TB8KZ`) reports `lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`
    at the bootloader level (lk2nd reads this from the stock aboot cmdline,
    not guessed), and we have **first-light confirmation on the actual
    glass** (2026-07-20, user-witnessed, documented in
    `docs/pmos-ofilm-panel.md` §7.4 "Ofilm vs Tianma delta" and porting-log).
    `aneesh-pradhan` already left a note on PR #48's review thread (not #6)
    flagging this: *"Old PR but I want to note that my Moto E4 (perry) has
    an Ofilm panel."* — but no PR exists yet adding the Ofilm entry.

### 2.3 Sibling multi-panel `config/*.sh` pattern (the template to copy)

Fetched via `gh api repos/msm89x7-mainline/linux-panel-drivers/contents/config/<name>.sh`.
Every other Motorola msm8917/8937 device in this fork ships **multiple**
panel entries in its `PANELS=()` array — perry's single-entry file is the
outlier, and that's exactly the gap:

```bash
# motorola-cedric.sh (msm8937)
OPTIONS=(--dumb-dcs)
PANELS=(
	[tianma_497_1080p_video_v0]="motorola,cedric-nt35596-tianma"
	[inx_497_1080p_video_v0]="motorola,cedric-nt35596-inx"
)

# motorola-hannah.sh (msm8937)
OPTIONS=()
PANELS=(
	[djn_599_hd_video_v0]="motorola,hannah-599-djn"
	[djn_600_hd_video_v0]="motorola,hannah-600-djn"
	[tianma_599_hd_video_v0]="motorola,hannah-599-tianma"
)

# motorola-montana.sh (msm8937)
OPTIONS=()
PANELS=(
	[tianma_521_1080p_video_v0]="motorola,montana-r63350-tianma"
	[inx_521_1080p_video_v0]="motorola,montana-nt35596-inx"
)

# motorola-nora.sh (msm8917 — same SoC family as perry!)
OPTIONS=()
PANELS=(
	[tianma_570_hd_video_v0]="motorola,jeter-570-tianma"
	[tianma_571_hd_video_v0]="motorola,jeter-571-tianma"
	[djn_570_hd_video_v0]="motorola,jeter-570-djn"
	[djn_571_hd_video_v0]="motorola,jeter-571-djn"
	[wistron_570_hd_video_v0]="motorola,jeter-570-wistron"
)
```

The Ofilm PR should add a **second entry** to perry's array (not a new
file), following our own `compatible` naming already validated on-device:

```bash
OPTIONS=()
PANELS=(
	[tianma_499_720p_video_v1]="motorola,perry-499v1-tianma"
	[ofilm_499_720p_video_v0]="motorola,perry-499v0-ofilm"
)
```

### 2.4 Our local carry — what already exists and maps to what

`pmos/linux-postmarketos-qcom-msm89x7/0001-0006` (mirrored into
`pmos/linux-motorola-perry/patches/`), already board-validated:

| Local patch | Maps to | Status vs upstream |
|---|---|---|
| `0001-Input-rmi_i2c-*.patch` | PR #48 commit `d3dc233` (Kaechele) | Clean, no changes needed — carry as-is |
| `0002-arm64-qcom-add-support-for-MSM8920.patch` | PR #48 commit `ceace8c` (Frederick) | Needs review fixes, see §4.2 |
| `0003-arm64-dts-qcom-add-support-for-motorola-perry.patch` | PR #48 commit `b87b04a` (Frederick), **with our own Makefile-typo fix already applied** | Needs review fixes, see §4.3 |
| `0004-drm-panel-add-motorola-perry-Tianma-499v1-panel.patch` | Generated from panel PR #6 via `lmdpdg --dumb-dcs` | Panel driver itself is fine; the *config* it was generated from needs the Ofilm sibling added (§4.4) |
| `0005-drm-panel-add-motorola-perry-Ofilm-499v0-panel.patch` | **Not upstream at all yet** — hand-converted by us from downstream `kernel/motorola/msm8953 dsi-panel-mot-ofilm-499-720p-video-common.dtsi` | This is the actual new contribution — needs to become a real panel-drivers PR |
| `0006-arm64-dts-qcom-perry-select-Ofilm-499v0-panel.patch` | **Not upstream** — hardcodes Ofilm as the DTS-selected panel for this unit, since lk2nd has no perry `lk2nd,panel` map to auto-select | Should stay a **local-only** patch even after upstreaming Ofilm support (see §5 step E) — upstream DTS should ship a placeholder/first-registered-panel default, not one unit's specific panel forced in the shared DTS |

**Do not re-derive any of this from scratch** — it's already correct,
board-tested, and the fastest path is diffing *against* it, not rewriting
it.

---

## 3. Technical background (so you don't have to reverse-engineer it again)

### 3.1 MSM8917 vs MSM8920 — what's actually different

MSM8920 is (per PR #48's own commit message, which is accurate) "essentially
MSM8917 with MSM8953's modem stack." Concretely, in `msm8920.dtsi`
(`#include "msm8917.dtsi"` as the base):

- Bigger reserved-memory regions for modem-adjacent firmware:
  `adsp_mem` (0x1100000), `gps_mem` (0x200000), `mba_mem` (0x100000),
  `venus_mem` (0x400000), `wcnss_mem` (0x700000) — all overridden vs
  whatever msm8917.dtsi sets by default.
- A new `apps_iommu` sub-node (`iommu-ctx@18000`) for IPA (IP Accelerator —
  Qualcomm's hardware packet-processing offload for the modem datapath).
- New `ipa@7900000` node, `compatible = "qcom,ipa-lite-v2.6"`, status
  `disabled` by default (perry's own `msm8920-motorola-perry.dts` flips it
  to `okay`).
- `rpmcc` compatible switched to `"qcom,rpmcc-msm8920", "qcom,rpmcc"`.
- Perry's MSM8920 variant DTS (`msm8920-motorola-perry.dts`) sizes `mpss_mem`
  (modem firmware region) to `0x6a00000` vs MSM8917 variant's `0x5000000` —
  the bigger modem stack needs more RAM reserved for its firmware blob.

### 3.2 The "8940 MSS" review question, decoded

`barni2000`'s comment *"Are you sure 8940 MSS is good for 8920?"* (on
`msm8920.dtsi:77`, which is the `ipa@7900000` node) is asking whether the
IPA/MSS (Modem SubSystem) integration numbers here were copied from an
MSM8940 reference platform rather than derived/verified for MSM8920
specifically. MSM8940 and MSM8920 are siblings in the same SoC family
(both are "MSM8917 + bigger modem" variants Qualcomm shipped), so copying is
a *plausible* starting point, but the reviewer wants it *confirmed*, not
assumed. **This needs upstream Qualcomm reference material or a working
MSM8940 device's DTS to cross-check against** — this is the single most
research-heavy item in the whole checklist. If you can't find solid
evidence, the honest move is to say so explicitly in the PR rather than
assert correctness you can't back up; reviewers respect "I checked X and Y,
here's what I found" even when inconclusive, far more than confident
hand-waving.

### 3.3 rpmcc / clk-smd-rpm — why it has to go upstream *first*

`drivers/clk/qcom/clk-smd-rpm.c` and
`Documentation/devicetree/bindings/clock/qcom,rpmcc.yaml` are **shared,
frequently-updated files used by every Qualcomm device in mainline Linux**,
not fork-local. The fork's CONTRIBUTING.md explicitly calls this class of
file out: touching shared upstream-maintained infrastructure needs to go
through the *real* upstream review process (linux-arm-msm mailing list /
LKML), because a fork-only patch to a shared file will conflict with every
future upstream rebase and isn't something the fork maintainer can
responsibly carry indefinitely. This is why step A in the roadmap (§5) is
sequenced *before* the perry DTS itself, even though the DTS is the part we
actually care about.

### 3.4 lk2nd panel-selection mechanism (relevant to step E)

From `docs/pmos-ofilm-panel.md` §7.2 (already researched in an earlier
session, verbatim facts, reusable here): lk2nd can read the downstream
bootloader's panel string via `lk2nd:panel` fastboot var, and if the
device's own lk2nd DTS entry has an `lk2nd,panel` compatible node, lk2nd
rewrites the mainline DTB's placeholder panel-node compatible at boot time
to match the detected hardware. **perry has no lk2nd device DTS entry
providing this map today** — only the device-identity node we already
upstreamed (`d9ce4e70` in `msm8916-mainline/lk2nd`, see
`docs/pmos-lk2nd-perry-node.md`). Multi-panel auto-selection for perry is a
**separate, optional future lk2nd PR** (roadmap step E) — do not conflate it
with the kernel/panel-driver work in steps A-D, which only need the panel
*drivers* and DTS *compatible strings* to exist; DTS-level default selection
without the lk2nd map is a legitimate (if imperfect) interim state, same as
our own local patch `0006` does today.

---

## 4. Full review-fix checklist (every comment, verbatim, with the fix)

This is the exhaustive, line-by-line version of the checklist already
summarized in issue #13. Each item cites the **exact file and line** from
the live PR (fetch commands in §2.1/§2.2 to re-verify if the PR has moved).

### 4.1 Process / PR structure

- [ ] **Split rpmcc out of the perry mega-PR; send it upstream first.**
  `drivers/clk/qcom/clk-smd-rpm.c` + `qcom,rpmcc.yaml` changes need their own
  series aimed at real upstream Linux (see §3.3, §5 step A), separate from
  the fork PR.
- [ ] **Commit messages need real descriptions**, not one-line headlines.
  `barni2000`: *"Add proper descriptions and your SoB for your commits"* —
  applies to the MSM8920 commit (`ceace8c`) and the perry-DTS commit
  (`b87b04a`); the touchscreen commit (`d3dc233`, Kaechele) is already fine.
- [ ] **`Signed-off-by` on every commit we author or materially rewrite.**
  Kaechele's and Frederick's original SoBs stay if we carry their commits
  unmodified in substance; add our own SoB to anything we rewrite (per DCO
  norms — SoB means "I attest I have the right to submit this," it stacks,
  it doesn't replace).
- [ ] **Panel commit stays split from the kernel PR** — `barni2000` already
  asked for this and it's already correctly split (panel PR #6 exists
  separately). Just don't regress this when re-rolling.

### 4.2 `msm8920.dtsi`

- [ ] **Line 60** (`&adsp_mem`/similar size override): *"It is enough to
  override the size where it is necessary"* — audit every `&foo_mem { size
  = ...; }` block; only keep overrides that actually differ from
  `msm8917.dtsi`'s inherited defaults, drop the rest.
- [ ] **Line 73**: *"Useless, it is exactly same in msm8917.dtsi"* — a
  specific node/property here is a no-op copy; find and remove it (re-diff
  against current `msm8917.dtsi` at fetch time, don't trust memorized values
  from this doc — upstream `msm8917.dtsi` may have changed since 2026-04).
- [ ] **Line 77** (`ipa@7900000`): *"Are you sure 8940 MSS is good for
  8920?"* — see §3.2. Needs actual research/evidence, not a guess.
- [ ] **Line 1**: *"GPL2.0-only"* — file currently ships
  `// SPDX-License-Identifier: BSD-3-Clause`; change to
  `GPL-2.0-only` to match the license of `msm8917.dtsi`, which it includes
  and derives from.
- [ ] **Line 3**: *"You should add your copyright here"* — current header is
  `Copyright (c) 2023, Dang Huynh <danct12@riseup.net>` only; whoever
  substantially adapts this file for the re-roll should add their own
  copyright line alongside it (do not remove Dang Huynh's — this is
  additive, reflecting derivative-work convention, not a replacement of
  original attribution).
- [ ] **rpmcc binding sync**: keep
  `Documentation/devicetree/bindings/clock/qcom,rpmcc.yaml`'s
  `qcom,rpmcc-msm8920` entries in sync with whatever the split-out rpmcc
  series (step A) ends up looking like upstream — this file may need to be
  re-derived once step A actually lands, not just copy-pasted from the
  current draft.

### 4.3 `msm8917-motorola-perry-common.dtsi`

- [ ] **Line 194-196** (pinctrl on the top-level node):
  ```suggestion
  	pinctrl-0 = <&panel_default>;
  ```
  and
  ```suggestion
  	pinctrl-names = "default";
  ```
  with a third line flagged *"Remove"* — `barni2000` wants
  `pinctrl-0`/`pinctrl-names` **moved onto the `panel@0` node itself**, not
  left at the top level, matching how montana/nora structure it. Diff those
  two sibling DTSIs directly to see the exact target shape before writing
  the fix.
- [ ] **Line 201**: *"Do this device have only 1 panel variant?"* — same
  question as panel PR #6 §2.2/§4.4; answer is **no**, at minimum Tianma +
  Ofilm. The DTS-level fix here is different from the panel-PR fix though:
  this is about whether `panel@0`'s `compatible` should be a placeholder
  (for lk2nd rewrite, see §3.4/§5 step E) vs hardcoded — for the *upstream*
  submission, hardcoding the more-common Tianma as default (matching how
  our own local `0006` currently hardcodes Ofilm for this specific unit) is
  probably the pragmatic upstream-acceptable answer, with a comment noting
  the known Ofilm variant exists. Don't block the whole series on solving
  multi-panel auto-select (that's step E, genuinely optional/future).
- [ ] **Line 230** (likely `pm8937_s5` regulator or similar): *"As far as i
  know 8917 is not need this"* — `barni2000` believes this node/regulator is
  unnecessary for MSM8917. **Counter-evidence: sibling nora (also MSM8917)
  keeps the equivalent node** — don't blindly drop it; find nora's DTS,
  compare the exact node, and either (a) find real evidence it's genuinely
  unneeded for perry specifically (e.g. it's PMI8950-only and perry uses a
  different PMIC combo), or (b) push back on the review comment with nora
  as evidence, or (c) test-remove and confirm boot still works if you ever
  do get device access (not required for this research phase — flag as
  "needs on-device verification" if you can't resolve it from DTS/schematic
  evidence alone).
- [ ] **Line 446 / 438**: *"Remove"* (line 446, likely a duplicate or dead
  pinctrl state node) and a rename suggestion:
  ```suggestion
  	panel_default: panel-default-state {
  ```
  (line 438) — consistent with the pinctrl-move fix above; the panel default
  pinctrl state node should be named `panel_default` (matching the label
  referenced at line 194's fix), not whatever it's currently called
  (probably `mdss_dsi_default` per issue #13's earlier summary — confirm by
  reading the actual file content at fetch time).
- [ ] **Line 521**: *"Can you link relevant part from `msm8952.c`?"* — this
  is about `qcom,wcn3660b` (the Bluetooth/WiFi combo chip compatible
  string); reviewer wants evidence from the downstream `msm8952.c` board
  file (or equivalent) that this chip ID is actually correct for perry.
  **Note: montana also uses `wcn3660b`** — that's circumstantial supporting
  evidence (same SoC family, same era Motorola device) but not the direct
  citation the reviewer asked for. Check if `~/android/lineage`'s downstream
  kernel tree (msm8953-based, but board files may reference the actual WCN
  part) has anything citable, or the stock firmware dump under
  `~/android/stock-perry-NCQS26.69-64-21/`.
- [ ] **Line 201 (separate comment, different reviewer)**:
  `aneesh-pradhan`: *"Old PR but I want to note that my Moto E4 (perry) has
  an Ofilm panel."* — this is **our own prior comment**, already posted.
  The actionable follow-through is opening the actual Ofilm panel PR (step
  D), not just having left the comment.

### 4.4 `msm8917-motorola-perry.dts` / `msm8920-motorola-perry.dts`

- [ ] **Both files, line 1**: *"GPL-2.0-only since msm8917.dtsi also
  licensed by that"* — currently `BSD-3-Clause`; change both.
- [ ] **Both files, line 3**: *"You should add your copy right here"* —
  current header is `Copyright (c) 2025 Val Packett` only (both files,
  identical); add whoever's doing the re-roll's own copyright, additively
  (same convention as §4.2's msm8920.dtsi fix — don't remove Val Packett's
  line, it's presumably the original template/boilerplate author).
- [ ] **File mode**: both files are currently `100755` (executable) in the
  PR — DTS files should never be executable, fix to `100644` on commit (a
  `chmod` + re-add, or just make sure your editor/git config doesn't
  preserve the bad mode when you check the files out).

### 4.5 Panel PR #6 (`linux-panel-drivers`)

- [ ] **`config/motorola-perry.sh:5`**: *"Do this device have only one panel
  variant?"* with `agrecascino`'s incorrect *"Pretty sure... never seen a
  qualcomm perry with anything other than the tianma"* reply — **answer this
  definitively with our first-light-confirmed Ofilm evidence** (§2.2) by
  adding the second `PANELS=()` entry and either commenting on #6 directly
  or opening a fresh PR that supersedes it (see §5 step D for which).

---

## 5. Phased roadmap (A → F, expanded)

Matches issue #13's table, each step expanded with concrete sub-tasks,
deliverables, and gates. **Work roughly in order** — later steps depend on
earlier ones landing or at least being submitted (a step doesn't have to be
*merged* upstream before starting the next one locally, but the *target*
for later steps may shift if earlier upstream feedback changes direction).

### Step A — `qcom,rpmcc-msm8920` + bindings, upstream-first

**Deliverable:** a clean, minimal series adding MSM8920 rpmcc support to
`drivers/clk/qcom/clk-smd-rpm.c` and
`Documentation/devicetree/bindings/clock/qcom,rpmcc.yaml`, submitted to
**real upstream Linux** (linux-arm-msm list via `git send-email`, or a
GitHub-mirror PR if the actual upstream workflow accepts that — check
current `MAINTAINERS` file / `Documentation/process/` for the qcom clock
subsystem's actual preferred contribution path, this may have changed by
the time you read this).

Sub-tasks:
1. Extract just the rpmcc-relevant hunks from PR #48's `ceace8c` commit
   (the `clk-smd-rpm.c` +31 lines and the 2-line `rpmcc.yaml` addition).
2. Address the `4.1`/`4.2` review comments that apply to this file
   specifically (binding sync, SoB, commit message).
3. Verify against **current upstream mainline Linux** (not the fork) —
   `clk-smd-rpm.c` may have been refactored since April; a clean cherry-pick
   might not apply anymore. Check `git log --oneline -- drivers/clk/qcom/clk-smd-rpm.c`
   on a fresh mainline checkout.
4. Write a proper commit message: what MSM8920 needs from rpmcc that
   MSM8917 doesn't (this should follow directly from the DTS work in step
   B — the clock IDs a working `msm8920.dtsi` actually references).
5. Submit upstream. This is the highest-latency step (real kernel subsystem
   review can take weeks) — don't block starting step B on this landing,
   just don't claim the fork PR is "upstream-clean" until it has.

### Step B — Minimal `msm8920.dtsi`

**Deliverable:** `msm8920.dtsi` with only the real deltas vs `msm8917.dtsi`,
addressing every §4.2 item.

Sub-tasks:
1. Fresh checkout of current `msm8917.dtsi` from `msm89x7-mainline/linux`
   (or wherever it now lives — verify the fork hasn't reorganized).
2. Diff current `msm8920.dtsi` (from PR #48) against it property-by-property
   to find which memory-region size overrides are genuinely different vs
   copy-paste no-ops (§4.2 lines 60/73).
3. Research the MSS/IPA question (§3.2/§4.2 line 77) — this is the
   highest-effort item; document findings even if inconclusive.
4. Fix license header + copyright (§4.2 lines 1/3).
5. Keep the `rpmcc-msm8920` compatible reference in sync with step A's
   actual landed shape.

### Step C — Refresh perry DTS series

**Deliverable:** `msm8917-motorola-perry-common.dtsi` +
`msm8917-motorola-perry.dts` + `msm8920-motorola-perry.dts`, all §4.3/§4.4
items addressed, submitted as a fresh PR (either a from-scratch replacement
PR, or pushing new commits to #48 if `agrecascino` re-engages — default
assumption is a fresh PR, since #48's author has been silent since April and
a stalled draft with unaddressed multi-month-old review comments is
generally cleaner to supersede than to force-push over).

Sub-tasks: work through §4.3 and §4.4 checklists item by item. Use our own
board-tested `pmos/linux-motorola-perry/patches/0002-*` and `0003-*` as the
functional starting point (they already boot XT1765 correctly) — the work
here is bringing that *content* up to upstream code-quality bar, not
re-deriving the DTS logic from zero.

### Step D — Panel drivers: Tianma refresh + Ofilm (new)

**Deliverable:** `linux-panel-drivers` PR(s) covering both Tianma (refresh
of #6, addressing §4.5) and Ofilm (genuinely new upstream contribution).

Sub-tasks:
1. Decide: extend #6 in place (if `agrecascino` engages) or open a fresh PR
   that supersedes it with both panels. Given #6's silence and the fact
   we're *adding* content (not just fixing), a fresh PR referencing/closing
   #6 is likely cleaner — use judgment based on repo activity at the time.
2. Add the second `config/motorola-perry.sh` entry (§2.3's exact target
   shown above).
3. The Ofilm **panel driver C source** itself already exists at
   `pmos/linux-postmarketos-qcom-msm89x7/patches/0005-*` (hand-converted
   from downstream `dsi-panel-mot-ofilm-499-720p-video-common.dtsi`, using
   the `mipi_dsi_multi_context` API matching the `lmdpdg` output style,
   already board-validated). The work here is reformatting/re-deriving it
   to match whatever `lmdpdg` would generate from a `dtb/motorola-perry.dtb`
   that actually contains the Ofilm panel node (the current
   `dtb/motorola-perry.dtb` in #6 likely only has Tianma — check whether it
   needs regenerating, or whether hand-conversion is acceptable upstream
   too, matching precedent).
4. Explicitly close the loop on the *"only one panel variant?"* question
   (§4.5) in the PR description or a review reply — this is the one place
   where simply stating the evidence (lk2nd panel string + on-glass
   confirmation) directly resolves an open reviewer question, which is
   unusually satisfying/high-signal as upstream contributions go.

### Step E — Optional: lk2nd `lk2nd,panel` map for perry (stretch, later)

**Deliverable:** a `msm8916-mainline/lk2nd` PR adding a perry `lk2nd,panel`
map node (tianma v0/v1/v2, ofilm v0, boe v0/v1, inx v0/v1 — see
`docs/pmos-ofilm-panel.md` §7.2 for the exact mechanism), so mainline boots
auto-select the correct panel per-unit instead of the DTS hardcoding one
variant.

**Explicitly optional and lower priority** — perry's lk2nd device-identity
node (unrelated to panel selection) is **already upstream**
(`d9ce4e70`, see `docs/pmos-lk2nd-perry-node.md`); this step is a *new*,
separate contribution for panel auto-detection specifically. Don't start
this until steps C/D are at least submitted — it depends on knowing the
final set of upstream panel `compatible` strings from step D.

### Step F — Shrink the xylitol overlay

**Deliverable:** once a tagged `linux-postmarketos-qcom-msm89x7` release
includes the upstreamed work, retire the now-redundant local patches from
`pmos/linux-postmarketos-qcom-msm89x7/` and `pmos/linux-motorola-perry/patches/`,
update `docs/perry-custom-kernel-plan.md` and this doc to reflect the new
(smaller) local carry, and note the change in `docs/porting-log.md`.

**Gate: do not start this until steps A-D have actually landed in a real
tagged release** — "PR opened" is not "PR merged and packaged." Track the
specific release/tag that includes the work when it happens.

---

## 6. Process / contribution rules (do not skip these — they're the actual bar)

From `msm89x7-mainline/linux`'s `CONTRIBUTING.md`
(https://github.com/msm89x7-mainline/linux/blob/msm89x7/7.1.3/CONTRIBUTING.md
— re-fetch, the branch/tag in that URL will drift):

1. **Upstream-first for shared files.** rpmcc / `clk-smd-rpm.c` /
   `qcom,rpmcc.yaml` (and any other file that touches infrastructure shared
   across many devices, not just perry) must go through real upstream
   review *before* the fork will merge a PR depending on it. This is §5
   step A.
2. **Clean commit split.** One logical change per commit, one subsystem per
   commit where reasonable. No mega-commits mixing kernel + DTS + panel +
   binding changes. (PR #48 already has 3 separate commits by
   subject — keep that discipline in any re-roll, and split further if a
   single commit ends up doing more than one thing after the review fixes.)
2a. **Proper commit messages.** Explain *why*, not just *what* — see §4.1.
3. **`Signed-off-by` (DCO) on every commit.** This is the mechanism that
   makes "picking up abandoned work" legitimate. Preserve original authors'
   SoBs on commits you carry substantively unmodified; add your own SoB to
   anything you write or materially rewrite.
4. **Upstream code-quality bar even for fork-only patches.** No compiler
   warnings, follow kernel style (`scripts/checkpatch.pl` if available),
   follow the standard kernel
   [Submitting patches](https://www.kernel.org/doc/html/latest/process/submitting-patches.html)
   process norms even though this is a fork, not mainline directly — the
   fork explicitly plans for eventual upstream submission of the
   qualifying pieces.
5. **Panels stay in `linux-panel-drivers`**, kept separate from the kernel
   DTS/driver PR, even though the fork will accept WIP/draft panels there —
   they're still held to the same formal-quality bar eventually.
6. **Fork merge ≠ mainline Linux acceptance.** Landing in
   `msm89x7-mainline/linux` is a staging step, not the end goal for the
   genuinely-shared files (rpmcc etc.) — those still need real
   linux-arm-msm/LKML submission per point 1. DTS and panel driver files
   are more fork/device-specific and may reasonably stay fork-only
   long-term, similar to how many device trees exist for years in
   postmarketOS-adjacent forks before (if ever) reaching mainline Linux
   directly.

---

## 7. Explicit non-goals / guardrails

- **No hardware flash, no `fastboot`, no `pmbootstrap install`.** This
  entire track is kernel-source/DTS research and patch-writing against
  *other people's GitHub repos* (`msm89x7-mainline/*`). It does not touch
  the phone, the xylitol pmOS build pipeline, or any local pmaports
  checkout.
- **No Android/LineageOS changes.** Separate track entirely (see
  `docs/handoff.md` §1 for that queue — RIL is the standing Android
  priority, untouched by this work).
- **Sacred partitions:** irrelevant here since no device interaction
  happens, but standing rule regardless — never touch `persist`,
  `modemst1`, `modemst2`.
- **Do not bundle this with `pmos/device-motorola-perry/` or
  `pmos/linux-motorola-perry/` edits.** Those are xylitol's own first-class
  packages (see `perry-custom-kernel-plan.md`) — a *different*, *separate*
  track from upstreaming to `msm89x7-mainline`. This plan's deliverables are
  PRs against **external repos** (`msm89x7-mainline/linux`,
  `msm89x7-mainline/linux-panel-drivers`, optionally
  `msm8916-mainline/lk2nd`), not commits to xylitol's own `pmos/` packages.
  Only §5 step F ever touches xylitol's own overlay, and only after
  upstream work has actually landed in a release.
- **Not a substitute for [xylitol#11](https://github.com/aneesh-pradhan/xylitol/issues/11)**
  (P3.3, upstreaming a perry deviceaport to pmaports) — that's a *different*
  upstream target (pmaports, the package-metadata layer) that depends on
  *this* work landing first (a packaged kernel needs to actually ship
  perry's DTB before a pmaports deviceaport pinning it makes sense).

---

## 8. Session opener (use verbatim to start a fresh session on this)

> Read `docs/pmos-upstream-kernel-plan.md` end-to-end — it's fully
> self-contained. This is upstream kernel/DTS/panel-driver research and
> patch-writing against **external GitHub repos**
> (`msm89x7-mainline/linux`, `msm89x7-mainline/linux-panel-drivers`,
> optionally `msm8916-mainline/lk2nd`) — it does **not** touch the xylitol
> pmOS build, does **not** need `pmbootstrap`/`fastboot`, and does **not**
> need the physical device. Tracking issue: xylitol#13. Start with §2
> ("Verified facts") to re-confirm nothing has drifted since 2026-07-21 (PRs
> may have been updated, closed, or superseded — re-run the `gh` commands in
> §2.1/§2.2 before trusting any specific line numbers or file states quoted
> in this doc), then work §5's roadmap roughly in order (step A's rpmcc
> split first, since the fork maintainer gated everything else on it). The
> full line-by-line review-comment checklist is in §4 — treat it as the
> actual acceptance bar, not this doc's summary of it. Do not start §5 step
> F (shrinking xylitol's local kernel overlay) until upstream work has
> actually landed in a tagged `linux-postmarketos-qcom-msm89x7` release, not
> merely been submitted.

---

## 9. Quick links

| What | Where |
|---|---|
| Tracking issue | [xylitol#13](https://github.com/aneesh-pradhan/xylitol/issues/13) |
| Kernel/DTS PR to adopt | [msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48) |
| Panel PR to extend | [msm89x7-mainline/linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6) |
| Fork contribution rules | [CONTRIBUTING.md](https://github.com/msm89x7-mainline/linux/blob/msm89x7/7.1.3/CONTRIBUTING.md) (re-verify URL/branch) |
| Kernel patch submission norms | [Submitting patches](https://www.kernel.org/doc/html/latest/process/submitting-patches.html) |
| Our local kernel carry (canonical) | `pmos/linux-motorola-perry/patches/0001-0006` |
| Our local kernel carry (legacy overlay, same patches) | `pmos/linux-postmarketos-qcom-msm89x7/0001-0006` |
| Ofilm panel research (reusable facts) | [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) |
| lk2nd perry node (already upstream, unrelated to panel map) | [`pmos-lk2nd-perry-node.md`](pmos-lk2nd-perry-node.md) |
| xylitol custom kernel/device package track (different track, do not conflate) | [`perry-custom-kernel-plan.md`](perry-custom-kernel-plan.md) |
| pmaports deviceaport upstreaming (depends on this work) | [xylitol#11](https://github.com/aneesh-pradhan/xylitol/issues/11) |
| Session state / overall project handoff | [`handoff.md`](handoff.md) |
