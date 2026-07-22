# Session handoff — perry / xylitol

> **Public build guide:** [`../README.md`](../README.md) ·
> [`flashing.md`](flashing.md) · [`blobs.md`](blobs.md) ·
> [`known-good.md`](known-good.md). This file is maintainer session state.

## ▶ Next session — start here (2026-07-22 EOD)

**⚑ PRIORITY:** **pmOS is primary.** Device track first. Upstream mail is
**parked** (do not `git send-email` rpmcc until asked). Android/Lineage
deferred. Modem **out of scope**.

**✅ 7.1.3 FLASHED + HARDWARE-VALIDATED (2026-07-22).** The phone now runs
**kernel `7.1.3-msm89x7`** (`linux-motorola-perry` **7.1.3-r1**). Clean flash
(`FLASH_COMPLETE`, 13/13 sparse chunks, 304s; chunk 12 = 187s eMMC latency,
not a hang). On-device SSH validated all green: `uname -r`=**`7.1.3-msm89x7`**,
Phosh (phoc PID + greetd + phrog greeter), Wi‑Fi `wlan0` connected
(`SnugglesCoffee`), ALSA card 0 `motorola-perry` + perry UCM + `speaker-test`
opens `hw:0,0`, Ofilm DSI-1 **connected**, **dmesg clean** (no call
trace/oops/panic — no 7.1.x kernel regression). No bootloop. Details in
[▶ 7.1.3 kernel rebase](#-71-kernel-rebase--flashed--validated) below.

**⇒ FIRST ACTION NEXT SESSION: contribute upstream** (the post-7.1.3 north
star) — panel [PR #8](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/8)
/ adopt [DTS #48](https://github.com/msm89x7-mainline/linux/pull/48); mail
rpmcc/step-A **only when the user asks** (still parked). Optional device
polish (§4) and RC publish (§3) remain available.

**One caveat to re-check:** PipeWire/WirePlumber read `inactive` because the
device sits at the **greeter** (nobody logged into a full Phosh session);
linger is on, the user manager session exists, and ALSA opens `hw:0,0`, so
audio is healthy — but do a post-login `wpctl status` (Speaker sink + Mic
source) next time a full session is up to close the loop.

### Device (live)

| Item | Value |
|---|---|
| Unit | XT1765 / `ZY224TB8KZ` |
| Image on phone | **7.1.3 first-class product image** (clean build from `main`, P1.5 off) |
| Kernel | **`7.1.3-msm89x7`** — `linux-motorola-perry` **7.1.3-r1** (newest `msm89x7-mainline/linux` tag; HZ=250) |
| Device pkg (on phone) | `device-motorola-perry` **1-r5** (no early ofilm; no fb-wait; P1.5 off by default) |
| Initramfs (on phone) | `postmarketos-initramfs` **3.12.0-r0** **unpatched** (no P1.5) |
| UI | **Phosh running** (phoc + greetd + phrog); Ofilm panel DSI-1 **720×1280**, connected |
| Net | USB-net `xylitol@172.16.42.1` (pw `xylitol`; host `172.16.42.2/24` on `enx*` / cdc_ncm); Wi‑Fi works (`wlan0` connected `SnugglesCoffee`) |
| Audio | ALSA card 0 `motorola-perry` + perry UCM; `speaker-test` opens `hw:0,0` (verify PW sink/source post-login) |
| Last checked | 2026-07-22 ~13:50 local — **7.1.3 flash validated**: `uname -r`=`7.1.3-msm89x7`, Phosh + Wi‑Fi + ALSA/UCM all up, DSI-1 connected, dmesg clean, no bootloop |

**Gap: CLOSED (2026-07-22).** Phone rebuilt from `main` and flashed to the
first-class product image (`device` **1-r5**, kernel **7.0.9-r1**, initramfs
**3.12.0-r0 unpatched**, **P1.5 absent** — verified on-device). No longer on
bisect r4. Flash was clean (`FLASH_COMPLETE`, 306s sparse write); on-device
SSH confirmed kernel/pkg versions, Phosh (`phoc`+greetd), Wi‑Fi connected, and
audio stack (card 0 `motorola-perry` + perry UCM + PipeWire/WirePlumber).
**Reconnect gotcha (confirmed again this flash):** the host `enx*` iface name
changes every boot (random gadget MAC), so a pinned `172.16.42.2` strands on a
dead iface and you get "no route to host" even though the device is healthy —
re-bind `172.16.42.2/24` to the *current* live `enx*` each reconnect, then ssh.

### ▶ 7.1.3 kernel rebase — FLASHED + VALIDATED

**Goal (user, 2026-07-22):** get perry production-grade on **upstream latest
Linux (7.1+)**, *then* contribute to the upstream PRs and send mail. This is
the new north star; the rebase below was step 1 — **step 1 is now DONE
(flashed + hardware-validated 2026-07-22).**

**✅ Flash + validation result (2026-07-22 ~13:50 local):** flashed from stock
fastboot via `./scripts/pmos-flash-phase-b-force.sh` — `FLASH_COMPLETE`, exit 0,
13/13 sparse chunks in 304s (chunk 12 = 187s eMMC latency, expected). Booted
clean, no bootloop; first boot cycled the USB-net link (~75s to sshd — normal
post-reflash). On-device SSH: `uname -r`=**`7.1.3-msm89x7`**, postmarketOS edge,
`graphical.target` active, Phosh up (phoc + greetd + phrog), `wlan0` connected
(`SnugglesCoffee`), ALSA card 0 `motorola-perry` + perry UCM + `speaker-test`
opens `hw:0,0`, Ofilm DSI-1 connected, `/usr/lib/modules/7.1.3-msm89x7`
present, **dmesg clean** (no call trace/oops/panic → no 7.1.x regression).
Open follow-up: confirm PW sink/source with `wpctl status` after a full Phosh
login (device was at the greeter).

**What's done and committed to `main`:**
- **`linux-motorola-perry` bumped `7.0.9-r0` → `7.1.3-r1`** — newest
  `msm89x7-mainline/linux` tag ("MSM8937 venus", 2026-07-19). APKBUILD:
  `pkgver=7.1.3`, new `_srcrel=1` + `_tag="$pkgver-r$_srcrel"` (release suffix
  decoupled from `pkgrel`), tarball sha512 updated + verified reproducible
  (pmbootstrap's independent download matched).
- **All 6 perry patches apply CLEAN on 7.1.3** — scouted before bumping; zero
  conflicts, none upstream yet (so still all carried). Only a pre-existing
  trailing-whitespace warning on `0002` (cosmetic, `git apply` exit 0).
- **Kernel compiles green on 7.1.3** — `pmbootstrap build linux-motorola-perry`
  ✅ (~18 min, no patch/config errors), `linux-motorola-perry-7.1.3-r1.apk`.
  7.0.9 config carried over with no unmet-symbol issues.
- **Full flashable image built** — `./scripts/pmos-build-phase-b.sh` produced
  `artifacts/pmos-phase-b/motorola-perry-phosh.{img,sparse.img}` (2026-07-22
  13:15), self-checks passed (**P1.5 absent**, kernel flavor **`7.1.3-msm89x7`**,
  device r5, unpatched initramfs). **NOTE: this overwrote the r5/7.0.9
  productize image (same filename)** — the on-disk artifact is now 7.1.3.

**DONE (2026-07-22):**
1. ✅ **Flashed the 7.1.3 image** — from stock fastboot,
   `./scripts/pmos-flash-phase-b-force.sh`, `FLASH_COMPLETE`.
2. ✅ **Validated on hardware** — `uname -r`=`7.1.3-msm89x7`, Phosh/Wi‑Fi/
   audio/panel all up, dmesg clean. No regression vs 7.0.9 observed.
3. ✅ **Docs updated** — Device table + headlines flipped to 7.1.3.

**Remaining (optional):** re-roll the overlay/RC on 7.1.3 (§3); post-login
`wpctl` audio confirmation. Rollback if a latent regression surfaces is
`pmos-perry-2026-07-21` (still known-good) + bisect 7.0.9↔7.1.3.

**Rebase safety net (new this session):** CI now guards the rebase —
`.github/workflows/kernel-patches.yml` runs `scripts/ci-check-kernel-patches.sh`
which downloads the exact pinned upstream tag and asserts all 6 patches still
apply (catches "bump tag, forget to re-roll a patch"). Plus
`.github/workflows/lint.yml` (shellcheck + apkbuild-lint). Merged in
[PR #18](https://github.com/aneesh-pradhan/xylitol/pull/18).

### CI / repo hygiene (this session)

- **[PR #17](https://github.com/aneesh-pradhan/xylitol/pull/17) merged** —
  `.gitignore` now ignores **future** `.github/` additions (existing tracked
  workflows stay tracked; `no-ai-coauthor.yml` + `twrp.yml` still run).
  `.cursor/` was already covered — left as-is. New tracked workflow files must
  be `git add -f`'d past this rule.
- **[PR #18](https://github.com/aneesh-pradhan/xylitol/pull/18) merged** — the
  CI above. Gotcha found + fixed while writing it: `grep|head`/`find|head`
  under `set -o pipefail` race (SIGPIPE→141), and `_srcrel` must default to `0`
  for pre-rebase APKBUILDs. Both fixed; self-tested green.

### Checklist gap-scan (`~/Downloads/perry.txt`, 2026-07-22)

Measured perry against a generic MSM8916-era port checklist. **Functionally
ahead of it** (device boots: Phosh/Wi‑Fi/audio/touch/display/charging/USB-net).
Real remaining gaps, priority order: (1) CI to build kernel+device pkg — **CI
patch-check + lint now DONE (§11)**; a full pmbootstrap image build in Actions
is still optional/heavy; (2) firmware pkg breadth + README — we package only
WCNSS Wi‑Fi NV (`firmware-motorola-perry-nv`); GPU fw is generic, BT/modem out
of scope; (3) UCM earpiece/headset verbs (already on polish list); (4) confirm
the notification-LED node is actually enabled (`leds_qcom_lpg` loaded, node
unverified); (5) doc niceties (`README.panel.md`/`README.power.md`). Items the
checklist wants done differently are **correct perry adaptations**, not gaps:
dwc3→chipidea USB, pm8916→pm8937/pmi8950, panel-simple DTSI→DRM panel drivers,
RNDIS→CDC-NCM. DTS itself is genuinely perry-tailored (memory carveouts,
regulators, pinctrl — see patch `0003`).

### Hang status (closed)

**Root cause: P1.5** (initramfs framebuffer-wait patch +
`deviceinfo_framebuffer_wait_seconds=35`). A/B/C failed; **D PASS**.
Canonical: [`phase-b-boot-hang-bisect.md`](phase-b-boot-hang-bisect.md).
**Do not re-enable P1.5.** Splash gap (~27s black) is expected until a safe
redesign exists.

### Done this arc (do not redo)

| Item | Notes |
|---|---|
| Bisect A/B/C FAIL, D PASS | Evidence under `artifacts/pmos-phase-b/` (gitignored) |
| Rollback known-good | `pmos-perry-2026-07-21` still recovery path |
| Repo: P1.5 off by default | `scripts/pmos-build-phase-b.sh` (`ENABLE_P15=1` research-only); deviceinfo documents disabled wait |
| T6 baselines | Plan [`perry-custom-kernel-plan.md`](perry-custom-kernel-plan.md) §5; boot ~46.5s; schedutil; mq-deadline; GPU simple_ondemand 19.2–598 MHz |
| P1.3 | Baselines only — **no GPU DT** until measured need |
| Audio smoke on Bisect D | Speaker OK |
| Upstream panel | [linux-panel-drivers#8](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/8) Tianma+Ofilm (open) |
| Upstream #48 note | Adoption comment on [msm89x7 linux#48](https://github.com/msm89x7-mainline/linux/pull/48) |
| Step A rpmcc | Staged [`upstream/rpmcc-msm8920/`](../upstream/rpmcc-msm8920/) — **not mailed** (user hold) |
| Git `main` tip (pushed) | `03e911e` and parents on `origin/main` |

### ▶ Do next (device track — agreed)

| # | Task | How |
|---|---|---|
| ~~**1**~~ | ~~**Flash + validate the 7.1.3 image**~~ | ✅ **DONE 2026-07-22** — flashed from stock fastboot (`FLASH_COMPLETE`), SSH-validated `uname -r`=`7.1.3-msm89x7`, Phosh/Wi‑Fi/audio/panel up, dmesg clean. See [▶ 7.1.3 kernel rebase](#-71-kernel-rebase--flashed--validated). |
| **2** | **Contribute upstream** (per user goal) — **now the first action** | 7.1.3 boots green, so: further work on [panel PR #8](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/8) / adopt [DTS #48](https://github.com/msm89x7-mainline/linux/pull/48), and (only when asked) mail the rpmcc/step-A patch. |
| ~~**P**~~ | ~~**Productize first-class Phase B**~~ | ✅ **DONE 2026-07-22.** Rebuilt from `main` (P1.5 off), flashed from stock fastboot (`FLASH_COMPLETE`). On-device validated: `device` **1-r5**, kernel **7.0.9-r1**, initramfs **3.12.0-r0 unpatched**, P1.5 absent; Phosh + Wi‑Fi + audio all up. |
| **3** | Optional RC publish | Stage/publish first-class image alongside overlay release `pmos-perry-2026-07-21` |
| **4** | Daily-driver polish (no rebuild) | Suspend/resume, Wi‑Fi after sleep, USB-net replug, earpiece/headset UCM; confirm notification-LED node |
| **5** | P1.5 redesign | Research only — bisect doc §4; single-variable tests only with recovery staged |

### Parked (do not start unprompted)

| Track | State |
|---|---|
| **Mail rpmcc / step A send-email** | Explicit hold — patch ready in-tree only |
| **Upstream B/C** (`msm8920.dtsi`, perry DTS re-roll) | After device productize or when asked |
| **Android / RIL / AF** | Deferred; Lineage still boots historically |
| **Modem / ModemManager** | Out of scope (no usable US bands on this unit) |

### Recovery

```bash
./scripts/pmos-rollback-known-good.sh
# → release artifacts/pmos-release/pmos-perry-2026-07-21/
```

Sacred: never `persist` / `modemst1` / `modemst2`. One agent owns fastboot;
no competing `getvar` loops.

### Build / flash cheat sheet (productize)

```bash
# Build (P1.5 off by default)
./scripts/pmos-build-phase-b.sh
# Flash from stock Motorola fastboot
./scripts/pmos-flash-phase-b-force.sh
# SSH after continue (~25s on Bisect D)
ssh xylitol@172.16.42.1   # pw xylitol; host 172.16.42.2/24 on enx*
```

### Headlines (current truth)

- **On-phone = `7.1.3-msm89x7`** first-class product image (`device` r5) —
  **flashed + hardware-validated 2026-07-22** (Phosh/Wi‑Fi/audio/panel/
  no-bootloop, dmesg clean). This is now the current known-good.
- **`7.1.3` rebase DONE** — committed to `main`, all 6 patches apply clean,
  kernel compiles, CI guards it, **and now flashed + validated on hardware.**
- **CI added** (PR #18): kernel-patch-apply + shellcheck/apkbuild-lint.
- **Overlay release** `pmos-perry-2026-07-21` (7.0.9) remains the rollback path.
- **Audio / Wi‑Fi / Ofilm / USB-net / Phosh** all work on the live 7.1.3 image.
- **User goal:** production-grade on Linux **7.1+** ✅ reached — *next:* upstream
  PRs + mail (mail still parked until asked).

**Meta-repo:** `main` synced to origin — PRs #17 (gitignore) + #18 (CI) merged;
7.1.3 APKBUILD rebase committed (see `git log`)  
**Lineage tree:** `~/android/lineage` (deferred)  
**pmOS work:** `~/pmos` · pmbootstrap 3.11.1  
**Device:** XT1765 / `ZY224TB8KZ`  
**pmOS backups:** `~/android/backups/perry/`  
**Stock:** `~/XT1765_PERRY_TMO_…` · unpack `~/android/stock-perry-NCQS26.69-64-21/`

Chronology: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md) · [`../AGENTS.md`](../AGENTS.md).

---

## Boot-hang incident — Phase B (2026-07-21 → 2026-07-22)

**Status: RESOLVED — root cause P1.5; Bisect D boots first-class path.**
Canonical write-up: [`phase-b-boot-hang-bisect.md`](phase-b-boot-hang-bisect.md).
Device at EOD 2026-07-22 runs Bisect D (see ▶ Next session above).

**Summary:** Phase B + P1.5 hung (black + backlight, no USB). A/B/C failed;
**D** (drop P1.5 only) **PASS**. P1.5 remains disabled in product builds.

**Historical detail** (original incident notes preserved below for
forensics).

### Symptom 1 — device frozen post-flash, does not reach Phosh

After the P1/P1.5 flash completed cleanly (`FLASH_COMPLETE`, confirmed in
porting-log) and `fastboot continue` handed off to the OS:

- Backlight turns on (so the Ofilm panel driver gets far enough to power the
  panel — this normally happens ~27s into boot per prior sessions).
- Screen stays **fully black** — no splash, no fbcon text, no `perry
  login:` tty. P1.5 raised the initramfs framebuffer-wait to 35s
  specifically so *something* should render by then.
- **No change for several minutes** (user-confirmed) — this is well past
  any plausible splash/console timing, so it is a real hang, not the old
  cosmetic ~27s-black-screen timing bug P1.5 was meant to fix.
- **Zero USB signal from the host the entire time it was frozen**: no
  `adb devices`, no `fastboot devices`, no `lsusb` entry at all, no
  `cdc_ncm` net interface. This rules out "just the display is broken,
  everything else is fine" (which would still show USB-net/SSH per the
  E-10 recipe) — the device was unreachable by every channel.
- User did a **fresh force power-off + power-on → "continue" on lk2nd**:
  identical result, no progress toward Phosh. Confirms it's reproducible,
  not a one-off glitch.
- User then forced the device into **stock/generic fastboot** (a
  dedicated Motorola key-combo, not lk2nd's Vol-Down interception — the
  `boot` partition still holds lk2nd from the prior flash's "restore
  normal lk2nd" step, so this bypasses it directly) to regain control.

**What's the same / different vs. the historical "blind & mute" Blocker B
(porting-log 2026-07-20):** same *shape* (silent, black, unreachable) but
that one was traced to DTB nodes (`simple-framebuffer status=disabled`,
`usb dr_mode=otg` extcon not firing) on the **stock qcom-msm89x7 kernel**,
long since retired as explanations (E-6: both confirmed correct-as-shipped,
not the fix). This is the **new first-class `linux-motorola-perry` P1
kernel** (HZ=250, eMMC mq-deadline, cpufreq audit, P1.5 initramfs patch)
— the only things that changed versus the last **validated-working** build
(`pmos-perry-2026-07-21` Phosh release). No serial console exists on this
device (no UART cable), so there is no way to see where in boot it's
actually stuck — diagnosis has to be by differential reflash/bisection, not
log inspection.

### Symptom 2 — fastboot itself went unresponsive during recovery (NEW, separate bug)

While driving recovery from this host (adb/fastboot are installed locally
and the phone was USB-connected to it):

1. `fastboot devices` / `fastboot getvar all` **succeeded once**, full
   output: `product: perry`, `board: perry`, `secure: yes`, `hwrev: P3B`,
   `storage-type: emmc`, `emmc: 16GB SAMSUNG QE63MB …`, `ram: 2GB SAMSUNG
   LP3 …`, `cpu: MSM8917`, `serialno: ZY224TB8KZ`, `cid: 0x0015`,
   `securestate: flashing_unlocked`, `reason: Volume down key pressed`,
   `imei:` present. This is genuine **stock** Motorola bootloader fastboot
   (not lk2nd — lk2nd's signature is `product: lk2nd-msm8952`, empty
   `version-bootloader`, serial `24b071b`). Nothing sacred-partition-adjacent
   looked wrong.
2. `dmesg` then showed an **unprompted** USB identity flicker: the device
   briefly presented as `18d1:d00d` "Android"/"Google", serial `24b071b`
   (lk2nd's documented fastboot signature) for ~1.3s, then dropped and
   re-enumerated as `22b8:2e80` "Fastboot perry S"/Motorola Inc., serial
   `ZY224TB8KZ` (stock) again. **User confirmed no button presses during
   this window.** Timing lines up with the tail end of the user's own
   power-cycle/force-fastboot sequence (plausible the device transiently
   passed through lk2nd's fastboot — since `boot` still holds lk2nd —
   before the dedicated stock-fastboot combo took over), assessed as
   probably-benign settling noise, **but not conclusively confirmed**.
3. **After that, `fastboot getvar <anything>` hung/timed out on every
   subsequent attempt** (6+ tries over ~2 minutes), while `fastboot
   devices` and `lsusb` continued to show the device enumerated normally
   the whole time (directly on the host's root hub, port 4 — **not** behind
   the flaky external hub on this desktop). No competing `fastboot`/`adb`
   process was holding the device (`ps aux` checked). **No flash or boot
   command was ever issued this session** — only read-only
   `getvar`/`devices` queries — so nothing done from this host caused it.

This means the device is currently **present at the USB-descriptor level
but not answering the fastboot protocol** — a state one level worse than
the original bug (which at least let stock fastboot respond fully once).
Starting a multi-minute `userdata` write against a wedged fastboot session
risks a **worse outcome than the current freeze** (partial/corrupt flash),
so **no flash has been attempted against this symptom** — recovery paused
here pending a cable/port replug to rule out a host-USB-side cause before
assuming a phone-side fault.

### Hypotheses (ranked, unconfirmed)

1. **P1 kernel scrub regression** (HZ=250 / mq-deadline / cpufreq audit) —
   most likely for Symptom 1, but doesn't cleanly explain Symptom 2 (fastboot
   hangs happen in the **bootloader**, before this kernel ever runs — worth
   noting as an inconsistency, not glossing over it).
2. **Host-side USB/cable/port issue** — plausible for Symptom 2 specifically;
   ruled *in* as the first thing to test (replug / different port or cable)
   before concluding anything about the phone.
3. **Marginal phone-side hardware** (connector wear, power/battery) — cannot
   be ruled in or out remotely; only physical inspection helps.
4. **Corrupted/partial prior flash** — the P1 flash's last `userdata` chunk
   took 187s and was judged "eMMC latency, not a hang" at the time (process
   was in `D` state, not dead) — plausible but not proven; a rollback flash
   to a known-good image will help confirm either way once fastboot is
   stable.

### Recovery plan — prepared, ready to run once fastboot responds reliably

**Do not run this until `fastboot getvar product` responds normally and
repeatedly** (replug cable/port first if it's still hanging).

Artifacts already staged locally (not in git — `artifacts/` is gitignored):

- Known-good rollback image: `artifacts/pmos-release/pmos-perry-2026-07-21/qcom-msm89x7-perry-phosh.img`
  (the durable, previously flash-validated Phosh release — this is what was
  working *before* today's P1 kernel/P1.5 changes).
- Regenerated as sparse: `artifacts/pmos-release/pmos-perry-2026-07-21/qcom-msm89x7-perry-phosh.sparse.img`
  (1.96 GB, via `img2simg`) — ready to flash.
- Force-fastboot lk2nd (reused, unmodified): `artifacts/pmos-phase-b/lk2nd-force-fastboot.img`.
- **Gotcha found, not yet explained:** two different `lk2nd-msm8952-perry.img`
  binaries exist in the repo artifacts with **different SHA256**:
  `artifacts/pmos-phase-b/lk2nd-msm8952-perry.img` = `b884ee70…`, vs.
  `artifacts/pmos-release/pmos-perry-2026-07-21/lk2nd-msm8952-perry.img` =
  `8d7851b4…`. Not yet root-caused (could be harmless rebuild
  non-determinism, e.g. an embedded build timestamp — **not verified**).
  Plan uses the **release's own copy** (`8d7851b4…`) for the final
  "restore normal lk2nd" step, to match the exact pairing that was
  originally validated for this rootfs rather than mixing in the phase-b
  copy. Worth root-causing properly once the device is stable again —
  if it's more than a timestamp, that's its own latent bug.

Flash sequence (mirrors `scripts/pmos-flash-phase-b-force.sh`, pointed at
the known-good rollback image instead of the suspect P1 build):

```bash
FORCE=artifacts/pmos-phase-b/lk2nd-force-fastboot.img
NORMAL=artifacts/pmos-release/pmos-perry-2026-07-21/lk2nd-msm8952-perry.img
SPARSE=artifacts/pmos-release/pmos-perry-2026-07-21/qcom-msm89x7-perry-phosh.sparse.img

# from STOCK fastboot (product: perry):
fastboot flash boot "$NORMAL"
fastboot boot "$FORCE"
# wait for product: lk2nd-msm8952 ...
fastboot flash -S 100M userdata "$SPARSE"   # ~5-10 min, do not interrupt
fastboot flash boot "$NORMAL"               # restore normal lk2nd
fastboot continue
```

**Decision tree after this flash:**

- **Known-good boots clean** → confirms the P1 kernel scrub (or P1.5
  initramfs patch) is the regression. Next: bisect by reverting one of
  HZ=250 / mq-deadline / cpufreq-governor changes at a time and reflashing
  — there is no serial console, so bisection-by-reflash is the only
  diagnostic route available.
- **Known-good ALSO hangs the same way** → points at the flash/eMMC path or
  a hardware fault, not the kernel code. Next: a full clean reflash (not
  incremental), and if that still fails, physical inspection (cable/port/
  battery) rather than more code changes.

**Sacred, unaffected throughout:** only `boot` (lk2nd, reversible, flashed
twice) and `userdata` (destructive there, expected/reversible in this
project's workflow) have been touched. `persist`/`modemst1`/`modemst2`/
`fsg` never in play.

### Coordination note for parallel agents

Only one physical device exists. If multiple agents are working this
concurrently:

- **Only one agent should hold the fastboot session / issue device
  commands at a time** — interleaved flashes or getvar calls from two
  agents will race and could produce a worse corrupted state than either
  symptom above.
- Safe to parallelize: preparing/reviewing revert patches for the P1
  kernel scrub (HZ=250 / mq-deadline / cpufreq — see
  [`perry-custom-kernel-plan.md`](perry-custom-kernel-plan.md)), and
  root-causing the two-different-lk2nd-checksum gotcha above (diff the two
  binaries, check build logs/timestamps embedded in each).
- Append findings to this section (with date) rather than overwriting —
  this is the coordination point of truth until the device boots again.

### ✅ RESOLUTION UPDATE (2026-07-21, afternoon session) — rollback BOOTS; incident root causes found

**Status: device recovered and running the known-good release image.
Symptom 2 resolved; Symptom 1 root-cause narrowed to Phase B image content
and now under bisection.** Chronology and detail also in porting-log
2026-07-21.

**Host-side clean-rebuild pass (done before any device write):**

- **lk2nd cache poisoning confirmed and fixed** — the two-different-SHA
  gotcha above is root-caused: a FORCE_FASTBOOT lk2nd build had overwritten
  the local `lk2nd-msm8952-22.0-r3.apk` without a pkgrel bump, so every
  later "up to date" install embedded FORCE as NORMAL (`b884ee70…` *is* the
  FORCE twin). Purged poisoned apks, rebuilt clean NORMAL (`8d7851b4…`,
  matches release), hardened `pmos-build-phase-b.sh` /
  `pmos-flash-phase-b-force.sh` to reject FORCE-as-NORMAL and stale sparse.
- Release raw re-derived from the SHA-verified `.zst`; fresh sparse via
  `img2simg`. Dirtied raws quarantined (`artifacts/quarantine-2026-07-21/`).
- Full clean Phase B rebuild (initramfs, kernel 7.0.9, device pkg, install
  `--zap`) produced verified artifacts + SHA256SUMS.

**Symptom 2 (fastboot protocol hang): CLEARED by user power-cycle.** After
the device was physically reset back into stock fastboot, `getvar` answered
instantly and passed a 10/10 stability gate (G2a) + full `getvar all` (G2b).
Assessed as a transient bootloader/USB wedge, not host or phone hardware.

**Rollback flash executed cleanly** (release NORMAL lk2nd `8d7851b4…` to
`boot`, FORCE RAM-booted only, release sparse to `userdata`, ~6 min) —
**device BOOTS to Phosh on the known-good image, user-confirmed login**
(user/password `xylitol`, not the pmOS default 147147). USB-net + SSH up
(note: gadget MAC is random each boot → host `enx…` iface name changes;
assign `172.16.42.2/24` to the *new* iface).

**Decision-tree outcome → Symptom 1 is Phase B image content**, not
flash/eMMC/hardware. Key differential evidence pulled from the running
known-good system (saved in `artifacts/pmos-phase-b/evidence-rollback-boot/`):

- Known-good initramfs `initramfs.load` = generic msm89x7 panel set and
  **does NOT contain `panel_motorola_perry_499v0_ofilm`** (panel binds later
  from rootfs); the Phase B `modules-initfs` added ofilm to early boot —
  the prime suspect (early `modprobe -a` hang before USB gadget setup).
- Known-good kernel is HZ=300 (stock msm89x7 config); Phase B P1 scrub is
  HZ=250 — bisect variant B if A doesn't resolve it.

**Bisect A ❌ FAIL (flashed 2026-07-21 ~21:24Z UTC, user-confirmed hang):**
`device-motorola-perry` r4 (ofilm out of `modules-initfs`) + kernel still
HZ=250. Flash clean (`FLASH_COMPLETE`, chunk 12/12 ~188s). After
`continue`: same Symptom 1 — backlight on, black screen, frozen, no USB.
**Conclusion: early ofilm modprobe is NOT the sole hang cause.**

**Bisect B ❌ FAIL (flashed 2026-07-21 ~21:53Z, SSH timeout 150s):**
`HZ=300` + ofilm-out-of-initramfs still hangs (black screen / no USB).
**HZ=250 is not the hang cause.**

**Bisect C ❌ FAIL (flashed 2026-07-21 ~23:46Z, user-confirmed hang):**
full upstream msm89x7 defconfig (`FUNCTION_TRACER=y`, `DYNAMIC_DEBUG=y`,
`HZ=300`, pkgrel=3) + ofilm-out-of-initramfs **still hangs** (backlight
on, black screen, no USB). Flash was clean (`FLASH_COMPLETE`).

**Ruled out (A/B/C):**
| Var | Result |
|---|---|
| Early ofilm in `modules-initfs` | ❌ not sole cause |
| `CONFIG_HZ=250` | ❌ not sole cause |
| Entire P1.1 defconfig scrub | ❌ not sole cause |

**Conclusion:** hang is in the **first-class `motorola-perry` /
`linux-motorola-perry` path as a package set** (or something shared
across all Phase B images: P1.5 initramfs wait, install recipe, DT
carry interaction) — not the easy config toggles. Known-good
`qcom-msm89x7` + overlay release still the validated baseline.

**Resolved into:** top-of-file [▶ Next session](#-next-session--start-here-2026-07-22)
and [`phase-b-boot-hang-bisect.md`](phase-b-boot-hang-bisect.md).

---

## Next to-dos

Two tracks on the same device. **pmOS is primary**; **Lineage/Android deferred**
but intact — queue at [§1](#1-open-issues--the-work-queue) when/if we return.

### ▶ Next session — start here (2026-07-21, post-flash checkpoint)

**⚠ Superseded by [▶ Next session (2026-07-22)](#-next-session--start-here-2026-07-22)
and [`phase-b-boot-hang-bisect.md`](phase-b-boot-hang-bisect.md).** Historical
checkpoint for the flash that triggered the hang; kept for forensics.

**State:** Published Phosh image works on hardware. Custom
`device-motorola-perry` + `linux-motorola-perry` are committed; P0, P1.1/1.2/1.4/1.6,
and **P1.5 (framebuffer-wait fix) are all repo-side DONE, build-validated, AND
now FLASHED** — see below. Modem/SIM work is **out of scope** — this unit
doesn't support current US tower bands, so calling/texting is impossible; do
not schedule modem work.

**✅ Flash checkpoint DONE (2026-07-21, later same session):** the fresh
Phase B image (P1 kernel scrub + P1.5 fix) was flashed to hardware via
`scripts/pmos-flash-phase-b-force.sh` — full success, `FLASH_COMPLETE`.
Sequence: stock fastboot (`product=perry`) → flash normal lk2nd to `boot` →
`fastboot boot` the force-fastboot lk2nd variant (RAM-only) → sparse
`userdata` flash (12× ~100MB chunks, ~5 min total; **the last chunk alone
took 187s to write — eMMC latency, not a hang**, don't panic if a chunk sits
for a few minutes) → normal lk2nd restored to `boot` → `fastboot continue`.
**IMPORTANT gotcha found this session:** `artifacts/pmos-phase-b/*.sparse.img`
and `lk2nd-force-fastboot.img` are **not regenerated by
`pmos-build-phase-b.sh`** (which only produces the raw `.img`) — the sparse
image must be freshly regenerated via `img2simg raw.img out.sparse.img`
before every flash, or you'll flash stale content. `lk2nd-force-fastboot.img`
doesn't need regenerating (lk2nd hasn't changed across these sessions), but
verify that assumption if lk2nd itself was ever rebuilt.
**Still needs (ask the user, don't assume):** visual/SSH confirmation that
(a) Phosh boots normally and (b) the P1.5 splash actually renders instead of
the old ~27s black screen. If confirmed, close
[GitHub #4](https://github.com/aneesh-pradhan/xylitol/issues/4) and
[GitHub #12](https://github.com/aneesh-pradhan/xylitol/issues/12); if not,
that's the next debugging thread.

**Do next (pick one track):**

1. **P1.3 — GPU opp / cooling** — now **unblocked** (device is flashed) —
   capture `mangohud`/`govstat` baselines over SSH, then author DT `0101`
   only if the numbers justify it (plan §5). Tracked as
   [GitHub #3](https://github.com/aneesh-pradhan/xylitol/issues/3).
2. **pmOS upstream kernel/panel adoption (NEW, 2026-07-21)** — fully
   self-contained research + patch-writing track, **no device needed at
   all**. Adopt the stalled draft
   [msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48)
   + land the missing Ofilm panel in
   [linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6).
   Tracked as [GitHub #13](https://github.com/aneesh-pradhan/xylitol/issues/13).
   **Full roadmap, verified facts, line-by-line review checklist, and a
   verbatim session opener are all in
   [`pmos-upstream-kernel-plan.md`](pmos-upstream-kernel-plan.md)** — read
   that file, not just this summary, before starting.
3. **Polish (opportunistic)** — phosh earpiece/headset UCM; sensors; cameras
   still DT-disabled. Display freeze fallback: `WLR_DRM_NO_ATOMIC=1` (already
   in device package). See GitHub #9/#10 for the larger cameras/sensors items.

**Already done (do not redo):**

- Audio UCM, Phosh UI, durable release `pmos-perry-2026-07-21`, Wi-Fi NV, lk2nd
  perry node carry, P0 (zram / lean install / WLR / USB nosuspend / presets),
  P1.1 scrub + P1.6 HZ=250, P1.2 OPP audit (no DT patch), P1.4 eMMC udev,
  **P1.5 framebuffer-wait fix** (see below). Build-validated:
  `linux-motorola-perry` **7.0.9-r1**, `device-motorola-perry` **1-r3**.

**P1.5 — earlier DRM console / shorter splash: DONE (repo-side, 2026-07-21).**
Root cause: `postmarketos-initramfs`'s `setup_framebuffer()` hardcodes a 10s
wait for `/dev/fb0`, but perry's Ofilm 499v0 DPU/DSI DRM driver doesn't bind
until ~27s in, so the initramfs always gave up before any splash could show.
Fix: `pmos/postmarketos-initramfs/0001-*.patch` adds a
`deviceinfo_framebuffer_wait_seconds` knob (default 10, unchanged for every
other device); perry's own `deviceinfo` raises it to 35. Applied via new
`scripts/pmos-apply-initramfs-perry.sh`, wired into
`scripts/pmos-build-phase-b.sh`. Not simplefb (see E-6 below — that stays
retired). Build-validated AND **flashed to hardware 2026-07-21** — on-device
visual confirmation (splash renders instead of black screen) is the one
remaining open item, pending user verification. Full write-up + gotchas
found while building this: porting-log 2026-07-21 "P1.5 framebuffer-wait
fix". Tracked as [GitHub #4](https://github.com/aneesh-pradhan/xylitol/issues/4).

**Canonical paths:** `pmos/linux-motorola-perry/` (defconfig + patches
0001–0006), `pmos/device-motorola-perry/`, `pmos/postmarketos-initramfs/`
(P1.5 patch), plan [`perry-custom-kernel-plan.md`](perry-custom-kernel-plan.md).
Published overlay path (`qcom-msm89x7` + `pmos-build-phosh-release.sh`) still
valid.

**Housekeeping (no action now):** drop `pmos/lk2nd/0001-*` + lk2nd `pkgrel`
bump once pmaports bumps lk2nd past `d9ce4e70`.

### ▶ Prior next-session note (2026-07-20 late) — archived

Superseded by the 2026-07-21 block above. Historical checklist items 1–3
(UCM / Phosh / durable release) remain DONE; modem / polish / custom-kernel
items folded into the new list.

### Done this session (pmOS) — for context

- ✅ **Durable Phosh + extras image + GitHub Release** —
  [pmos-perry-2026-07-21](https://github.com/aneesh-pradhan/xylitol/releases/tag/pmos-perry-2026-07-21).
  `scripts/pmos-build-phosh-release.sh`; linger baked into deviceinfo pkgrel 1;
  loop-mount sanity PASS; **on-device reflash PASS** (Phosh + fdt + UCM + NV +
  wlan0).
- ✅ **Phosh mobile UI — USER-CONFIRMED SUCCESS.** perry was a UI=none console
  install; `apk add postmarketos-ui-phosh` (run via `systemd-run` transient unit
  so session-teardown didn't reap it) → clean boot to `graphical.target` +
  greetd + phrog greeter + phosh session (`xylitol`). phoc modesets DSI-1
  **720×1280@60**, EGL/GBM (Adreno 308 GL), touch works. Benign: intermittent
  DSI-1 "Atomic commit failed: Resource busy" (~0.1%; fix = `WLR_DRM_NO_ATOMIC=1`
  if ever visible). greetd config: `/etc/phrog/greetd-config.toml` →
  `/usr/libexec/phrog-greetd-session`, vt7. Details: porting-log 2026-07-20
  "Phosh mobile UI".
- ✅ **Audio — perry ALSA UCM profile** — was mute (`alsaucm -2`, "no backend
  DAIs"); no perry UCM shipped by `alsa-ucm-conf`. Authored
  `conf.d/motorola-perry/motorola-perry.conf` (potter HiFi verb + msm8x16-wcd
  codec seqs, every control verified on-card). Routing works (`PRI_MI2S_RX ←
  MultiMedia1` + `SPK DAC` on), `aplay hw:0,0` streams clean, WirePlumber
  exposes Speaker sink + Primary Mic source. Also disabled the crash-looping
  WirePlumber libcamera monitor and enabled `loginctl` linger (both flapped the
  audio nodes, not the UCM). Durable: pmaport `pmos/alsa-ucm-motorola-perry/` +
  `scripts/pmos-{apply,install}-perry-ucm.sh`. Details: porting-log 2026-07-20
  "pmOS audio". **Audible output user-confirmed 2026-07-20.**
- ✅ **lk2nd perry device node** — built (r3), flashed, hardware-validated:
  lk2nd now IDs `Motorola Moto E4 (perry)` (no FIXME/`-1`), pmOS boots through
  it. Already upstream (`d9ce4e70`); our patch is a temporary backport.
  [`pmos-lk2nd-perry-node.md`](pmos-lk2nd-perry-node.md).
- ✅ **Solution-2 DTB hacks (`fb=okay`/`usb=peripheral`) RETIRED** — evidence
  (all siblings ship simplefb disabled + `dr_mode=otg`); no overlay change.
- ✅ **fdt installer hardened** — `pmos-install-perry-deviceinfo.sh` now
  asserts an explicit `fdt` (fails on `fdtdir`/wrong DTB count).

### Done earlier this session (pmOS) — for context

- ✅ **Blocker B cleared** — pmOS boots to a full userspace (`7.0.9-msm89x7`
  aarch64), reachable over USB-net + SSH.
- ✅ **Wi-Fi working** — root-caused the missing perry WCNSS NV; runtime
  installer `scripts/pmos-install-wcnss-nv.sh` + **durable download-based
  pmaport** `firmware-motorola-perry-nv` (PR
  [#2](https://github.com/aneesh-pradhan/xylitol/pull/2)).
- ✅ **Ofilm 499v0 panel first-light** — user-confirmed on the glass.
- ✅ **Committed + pushed** — pmOS docs/overlay/patches on `main`
  (`9ac5652`, `44bbc41`, `9345c36`); public reproduction guide
  [`pmos.md`](pmos.md); firmware pmaport squash-merged via PR
  [#2](https://github.com/aneesh-pradhan/xylitol/pull/2) (`9c4f3a2`).
- ✅ **Feature-matrix walk** — BT/Wi-Fi/display/touch/GPU/accel/battery OK;
  audio needs UCM; cameras/vibrator/prox/ALS/GPS missing or disabled; modem
  AT OK (no SIM). See porting-log 2026-07-20 feature-matrix.
- ✅ **Durable extlinux `fdt`** — `/etc/deviceinfo` + pmaport
  `deviceinfo-motorola-perry`; **runbook-validated** (apk-regen +
  cold reboot PASS). Runtime: `scripts/pmos-install-perry-deviceinfo.sh`.
  Plan/runbook: `pmos-fdt-brick-fix-plan.md` / `pmos-fdt-fix-runbook.md`.

### pmOS — next (prioritized)

| # | Task | Notes / where |
|---|---|---|
| 1 | **Merge PR #2** (firmware pmaport) | ✅ Done 2026-07-20 — squash-merged as `9c4f3a2` on `main`. |
| 2 | **Feature-matrix walk** over SSH | ✅ Done 2026-07-20 — results in porting-log. BT/Wi-Fi/display/touch/GPU/accel OK; audio needs perry UCM; cameras (`camss`/`cci` disabled), vibrator, prox/ALS, GPS missing. |
| 3 | **Durable extlinux `fdtdir`→`fdt`** (E-6) | ✅ Done + **runbook-validated** 2026-07-20 — apk-regen + cold reboot keep `fdt`. Pmaport `deviceinfo-motorola-perry`. |
| 4 | ~~Fold DTB `fb=okay`/`usb=peripheral` into the overlay~~ (E-6) | ✅ **Resolved 2026-07-20 — RETIRED, no change.** Evidence: all 4 siblings on this kernel (nora/montana/cedric + perry) ship `simple-framebuffer status="disabled"` and `dr_mode="otg"`; device boots fine with both (real Ofilm DRM console + USB-net). Both were bring-up hacks now served by real drivers; folding either in would diverge from the family (usb=peripheral also breaks OTG host). Early splash, if ever wanted, = initramfs timeout bump (#6), not simplefb. See porting-log 2026-07-20 "Retire Solution-2 DTB hacks". |
| 5 | ~~Add perry lk2nd device node~~ | ✅ **DONE — flashed + validated 2026-07-20.** Patch `pmos/lk2nd/0001-*` adds `motorola-perry` to `msm8917-mtp.dts`; built lk2nd **r3** (`scripts/pmos-apply-lk2nd-perry.sh`), flashed to `boot`. Runtime: lk2nd logs `Detected device: Motorola Moto E4 (perry) (MSM8917) (compatible: motorola,perry)` (no FIXME/`-1`); pmOS boots through it (7.0.9-msm89x7, USB-net+SSH, wlan0). `fdtdir` now resolves natively (complements the deviceinfo `fdt` pin). Details: [`pmos-lk2nd-perry-node.md`](pmos-lk2nd-perry-node.md). |
| 6 | ~~Cosmetic: initramfs splash timeout~~ (P1.5) | ✅ **Repo-side DONE 2026-07-21** — `deviceinfo_framebuffer_wait_seconds` patch to `postmarketos-initramfs`, perry set to 35s. Build-validated; needs a flash to visually confirm. See [Next to-dos](#-next-session--start-here-2026-07-21) and porting-log 2026-07-21. |
| 7 | **USB-net stability** | Gadget auto-suspends, wiping the host IP. If iterating a lot: pin a NetworkManager profile for the cdc_ncm iface and/or disable device autosuspend. |
| 8 | **(optional) Device-exact NV in the pmaport** | Mirror NV (`3076c1a0…`) ≠ this unit's stock NV (`4f88c4c5…`, in backups). RF/regulatory cal only; MAC is SoC-derived. Bake stock in if you want this exact XT1765's cal — see [`pmos.md`](pmos.md) step 6. |
| 9 | **(optional) Upstream contributions** | lk2nd perry node is **already upstream** (`d9ce4e70`) — no PR needed. Still worth reporting: Ofilm-v0 panel detection to linux-panel-drivers#6 / linux#48, and the pmaports NV path mismatch. |

### Lineage/Android — next (unchanged priority)

Full board in [§1](#1-open-issues--the-work-queue). Top items:

| # | Task | State |
|---|---|---|
| 1 | **RIL / mobile network** | **PRIORITY**, untouched. GSM only; never touch `persist`/`modemst*`. |
| 2 | **Camera autofocus** | Open research. Preview/still OK (**0015**); AF `Invalid-region`. Do not re-ship stock `sensor_modules` with montana ISP. Three approaches in §P1a. |
| 3 | Sepolicy pass, hardware audit, release hygiene | §P2/§P3 (fstab `forceencrypt`, drop the `TARGET_KERNEL_VERSION := 4.9` lie, push/fork decision). |

**Cross-cutting rules (both tracks):** SACRED — never wipe/repartition
`persist` / `modemst1` / `modemst2`. No blobs / `out/` / Lineage tree in
xylitol git. No AI co-author trailers on commits or PRs. Never raw-dd a sparse

**AI co-author scrub (2026-07-21):** history rewritten (Claude trailers removed); main→main1→main dance re-run; hooks+CI+AGENTS.md enforce the ban.
`vendor.img`.

---

## Phase E pmOS — FLASHED and BOOTING (SESSION 2026-07-20)

**pmOS now boots to a full userspace with Wi-Fi, display, and USB/SSH — see
the [Next to-dos](#next-to-dos-2026-07-20-end-of-session) board for what's
left.** The user opened the Phase-E gate ("fully commit to flashing pmOS").
We flashed lk2nd + the pmOS rootfs and drove the boot failure through several
root causes to a working system: extlinux `fdtdir`→`fdt`, the "blind & mute"
kernel (Blocker B, now cleared), the missing WCNSS Wi-Fi NV, and Ofilm panel
first-light. Everything reversible; **sacred partitions never touched**
(confirmed present in lk2nd's own partition dump). The subsections below are
the chronological bring-up log; the consolidated state + to-dos are up top.

### E-0. Opener for next session (use verbatim)

> Read docs/handoff.md — start with the "Next to-dos" board, then this
> Phase E section. pmOS BOOTS on perry (XT1765): full postmarketOS edge
> userspace (7.0.9-msm89x7 aarch64), Wi-Fi + Ofilm display + USB/SSH all
> working. Reach it over USB-net: self-assign 172.16.42.2/24 on the cdc_ncm
> iface, `ssh xylitol@172.16.42.1` (sudo pw xylitol); link auto-suspends so
> re-add IP + timeout-wrap ssh. Blocker B (blind & mute), Wi-Fi (WCNSS NV),
> panel first-light, and the durable NV pmaport (PR #2 merged) are all DONE.
> Feature matrix walked (see porting-log). Durable extlinux `fdt` pin DONE
> and runbook-validated (apk-regen + cold reboot). Next: perry lk2nd device
> node (panel auto-select / "Unknown FIXME"), or audio UCM / fold `fb=okay`
> into overlay. Do not touch persist/modemst*.

### E-1. What we did, in order (all succeeded)

1. **Pre-flight verified:** device on adb; r2 kernel apk with Ofilm panel
   (`panel-motorola-perry-499v0-ofilm.ko.zst`) + `msm8917-motorola-perry.dtb`
   installed in rootfs chroot; combined image
   `~/pmos/work/chroot_native/home/pmos/rootfs/qcom-msm89x7.img` (1.28 GiB,
   also symlinked `/tmp/postmarketOS-export/qcom-msm89x7.img`); backups
   present (`~/android/backups/perry/`: `lineage-boot-2026-07-20.img`,
   `twrp-pmos-pre-D-20260720-1656/`, `sdcard-pre-D/` incl. `lineage.zip`).
2. **E1 `pmbootstrap flasher flash_lk2nd`** (from STOCK fastboot) → writes
   lk2nd (314 KB) to the **`boot`** partition. "Image not signed or
   corrupt" is the NORMAL unlocked-Moto warning; it writes anyway (OKAY).
3. **E2 reboot into lk2nd fastboot** (`fastboot reboot`, hold Vol-Down).
   Confirmed lk2nd: `product: lk2nd-msm8952`, `lk2nd:device: perry`,
   `lk2nd:version: 22.0-r2-postmarketos`, empty `version-bootloader`.
   **lk2nd's USB fastboot serial is `24b071b`** (stock aboot serial is
   `ZY224TB8KZ`) — handy tell for which bootloader you're in.
4. **E3 `pmbootstrap flasher flash_rootfs`** (from lk2nd fastboot) → writes
   the combined rootfs disk image to **`userdata`** (sparse, ~95 s). This
   is the destructive step (wiped Lineage userdata; covered by D2 backup).
   "Invalid sparse file format at header magic" is normal fastboot chatter.
5. **E4 boot → FAILED to reach pmOS.** Debugging below.

### E-2. lk2nd behaviour learned (write this on your bones)

- **lk2nd enters fastboot ONLY when Volume-Down is held while booting**
  (per lk2nd README). **USB being plugged does NOT force fastboot.** Vol-Up
  = recovery. No key = normal boot / OS.
- lk2nd shows an on-screen **menu** (reboot / continue / recovery /
  bootloader / EDL / shutdown) when a volume key is held or when it falls
  back after a failed OS boot. "continue" = resume/boot the OS.
- When lk2nd **cannot boot the OS, it FALLS BACK to fastboot mode** and
  shows its menu. So "phone sits in lk2nd on power-on with no key held" ==
  "lk2nd tried to boot and failed."
- **`fastboot oem log && fastboot get_staged <file>`** dumps lk2nd's
  internal ring-buffer log. THIS IS THE #1 DEBUG TOOL. The log persists
  within one lk2nd instance (a reboot / selecting "bootloader" restarts
  lk2nd and clears it — grab the log from the SAME instance that failed).
- lk2nd fastboot USB **enumeration is flaky**: bare `fastboot` blocks
  forever ("< waiting for any device >"). **Always wrap fastboot in
  `timeout N`** and retry a few times.
- `"Unknown (FIXME!)"` on the lk2nd screen + `Failed to find matching
  lk2nd device node: -1` in the log == **lk2nd has NO perry device entry**
  (cosmetic for identity, but see Blocker A — it breaks `fdtdir`).
- To reflash after a hang: force power-off (**hold Power ~10–15 s**), then
  **hold Vol-Down + tap Power** → lk2nd fastboot.

### E-3. Blocker A — lk2nd would not boot the install (FIXED)

**Symptom:** every boot fell back to lk2nd fastboot; USB-net never came up.

**lk2nd log (captured via oem log) — the money quote:**
```
block devices:
 | wrp0p53p1 |          |  826 MiB | Yes |   <- pmOS root (nested in userdata)
 | wrp0p53p0 |          |  487 MiB | Yes |   <- pmOS_boot (nested in userdata)
 | wrp0p53   | userdata | 10269 MiB|     |
...
boot: Trying to boot from the file system...
The dtb-files for this device is not set
Failed to parse extlinux.conf
boot: Bootable file system not found. Reverting to android boot.
ERROR: Invalid boot image header
ERROR: Could not do normal boot. Reverting to fastboot mode.
```
So lk2nd **does** find the nested `pmOS_boot`/root partitions inside
`userdata` (the pmbootstrap "self-contained disk image flashed to
userdata" model works) and reaches filesystem boot — but aborts.

**Root cause (confirmed in lk2nd source `lk2nd/boot/extlinux.c`,
`expand_conf()` ~L370-440):** our generated `extlinux.conf` used
**`fdtdir /`**. For `fdtdir`, lk2nd calls `lk2nd_device_get_dtb_hints()`;
since perry has **no lk2nd device node**, that returns NULL →
`"The dtb-files for this device is not set"` → abort. The `/boot` dir also
contains EVERY generic-port device's DTB (cedric/nora/xiaomi/…/perry), so
"auto-pick" needs the hints perry lacks. lk2nd's parser DOES support an
explicit **`fdt <path>`** / `devicetree` (CMD_FDT, cmd table ~L48-59),
which takes the `else` branch and needs NO device node.

**FIX (Solution 1):** rewrite the boot line to an explicit DTB:
```
    fdt /msm8917-motorola-perry.dtb      # was:  fdtdir /
```
Applied by loop-mounting the flashed image's `pmOS_boot` and editing
`extlinux/extlinux.conf`, then `flash_rootfs` again. **Result: lk2nd now
loads kernel + perry DTB and jumps to it** (fastboot disappears, USB goes
silent → kernel is executing). Blocker A cleared.

### E-4. Blocker B — kernel executes but was SILENT — **CLEARED 2026-07-20**

**RESOLVED.** The kernel boots to a full pmOS userspace and is reachable over
USB-net + SSH (confirmed this session: `ssh xylitol@172.16.42.1`, uptime,
`nmcli`, `dmesg` all live). Whatever combination of the Solution-2 DTB edits /
panel bring-up did it, "blind & mute" is no longer the state — the device
reaches multi-user, NetworkManager, and WiFi. **First on-boot task: bring up
USB-net** — the gadget is CDC-NCM at `172.16.42.1`; the host must self-assign
`172.16.42.2/24` (no DHCP lease is offered) and the link auto-suspends, so
re-add the IP + wrap ssh in `timeout` each reconnect. **WiFi is fixed** (see
below / porting-log). The historical "blind & mute" diagnosis is kept below
for the record.

#### (historical) Blocker B — kernel executes but is SILENT

**Symptom:** after the extlinux fix, `fastboot continue` → lk2nd hands off
(fastboot gone), **no USB-net for 6+ min**, host `dmesg` shows the lk2nd
gadget disconnect then **total USB silence** (no kernel gadget), screen
stuck on lk2nd's last framebuffer. Looks hung.

**Diagnosis — probably NOT a hang; a "blind & mute" kernel.** Read the
perry DTS we ship (`pmos/linux-postmarketos-qcom-msm89x7/0003-*.patch`):
- `chosen { stdout-path = "framebuffer0"; framebuffer0:
  framebuffer@90001000 { compatible="simple-framebuffer"; …
  status = "disabled"; }; }` → **console points at a DISABLED
  framebuffer** and there's no UART cable → kernel has **no console at
  all** → nothing on screen even if it's booting fine.
- `&usb { dr_mode = "otg"; extcon = <&pmi8950_smbcharger>, <&usb_id>; }`
  → gadget only enumerates if extcon role-detection flips to
  **peripheral**; if it doesn't fire (common in early bring-up) →
  **no RNDIS → no `172.16.42.1`**, indistinguishable from a hang.

**Kernel config supports both fixes** (checked `/boot/config` in rootfs):
`CONFIG_DRM_SIMPLEDRM=y`, `CONFIG_FB=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y`
(so enabling the fb node gives an on-screen console + simpledrm→DRM
handover), `CONFIG_USB_GADGET=y`, `CONFIG_USB_CONFIGFS=m` (RNDIS/NCM/ECM
present; configfs is an initramfs-loaded module).

**Solution 2 (PREPARED, host-side, DTB-only — verify if reflashed):**
Edited the perry DTB in the flashed image (no kernel rebuild):
- `framebuffer@90001000` `status "disabled"` → **`"okay"`** (on-screen
  console; even before the Ofilm DRM driver loads).
- `&usb` `dr_mode "otg"` → **`"peripheral"`** (force gadget → USB-net/SSH).
Method: `sudo apt-get install device-tree-compiler` (host now has dtc
1.7.2); loop-mount image `pmOS_boot`; `dtc -I dtb -O dts` the
`/msm8917-motorola-perry.dtb`; edit those two lines; `dtc -I dts -O dtb`;
write back to BOTH `/msm8917-motorola-perry.dtb` and
`/dtbs/qcom/msm8917-motorola-perry.dtb` (DTB grew 50523→50527 B); unmount.
**Image is patched; the reflash + boot was NOT yet done when this handoff
was written** (phone was being recovered to lk2nd fastboot). Next session:
confirm state, `flash_rootfs`, `fastboot continue`, watch screen + USB.

**Expected outcomes of Solution 2 boot:**
- Panel shows scrolling kernel/boot text → kernel is alive; read where it
  goes / hangs. And/or USB-net at `172.16.42.1` → `ssh xylitol@172.16.42.1`
  (key baked in), then `dmesg` tells us everything (incl. Ofilm panel).
- If framebuffer shows boot then freezes at a point → that's the REAL
  early hang; debug that DTS node (compare vs booting sibling nora/montana,
  same kernel).

### E-5. Reflash / boot recipe (fast iteration, no kernel rebuild)

```bash
export PATH="$HOME/bin:$PATH"
IMG=$HOME/pmos/work/chroot_native/home/pmos/rootfs/qcom-msm89x7.img
# --- edit files inside pmOS_boot (partition 1, ext2, 487 MiB) ---
LOOP=$(sudo losetup -fP --show "$IMG")     # ${LOOP}p1=pmOS_boot ${LOOP}p2=root
sudo mount "${LOOP}p1" /mnt/x              # extlinux/extlinux.conf, *.dtb, dtbs/
# ...edit...
sync; sudo umount /mnt/x; sudo losetup -d "$LOOP"
# --- phone must be in lk2nd fastboot (hold Vol-Down + Power) ---
timeout 8 fastboot getvar product          # expect: lk2nd-msm8952
pmbootstrap flasher flash_rootfs           # sends THIS image (sparses live), ~95 s
timeout 10 fastboot continue               # lk2nd boots the kernel
# watch: ip -brief addr | grep -iE 'usb|enx'; ping 172.16.42.1; ssh xylitol@172.16.42.1
```
Notes: `flash_rootfs` does NOT regenerate — it flashes the current raw
`qcom-msm89x7.img`, so loop-mount edits survive. `pmbootstrap install`
DOES regenerate (would overwrite extlinux via boot-deploy → back to
`fdtdir`). So for iteration, edit-image + flash_rootfs; don't re-run
install unless you also re-apply the extlinux/DTB fixes.

### E-6. DURABLE fixes still owed (we've been using throwaway image hacks)

Both Solution 1 (extlinux `fdt`) and Solution 2 (DTB fb/usb) are edits to
the *flashed image*, lost on any `pmbootstrap install`. To make them
reproducible in the xylitol overlay:
- **extlinux `fdtdir`→`fdt`:** ✅ Durable via `/etc/deviceinfo` pin
  (`deviceinfo-motorola-perry` pmaport). boot-deploy now emits
  `fdt /msm8917-motorola-perry.dtb` on every mkinitfs. Remaining "proper"
  fix is still a perry lk2nd device node (also panel auto-select /
  "Unknown FIXME!") — see to-do #5.
- **DTB fb=okay:** ✅ **RETIRED — do NOT fold in** (decided 2026-07-20).
  All four siblings on this kernel (nora/montana/cedric + perry) ship
  `framebuffer@90001000 status="disabled"`; perry already matches. The
  device boots with it disabled — the real Ofilm DRM driver provides the
  console (~27 s). We have *no* positive evidence enabling simplefb works on
  perry, it needs a kernel rebuild+flash to test, and it risks a garbage
  splash / clock-GDSC handover contention. Enabling it alone would diverge
  from the whole family for a purely cosmetic gain. Early splash, if ever
  wanted, = initramfs timeout bump (to-do #6), not simplefb.
- **DTB usb=peripheral:** ✅ **RETIRED — do NOT fold in** (decided 2026-07-20).
  All siblings + perry use `dr_mode="otg"`, and USB-net enumerates on the
  booted device with `otg`. `peripheral` was a Blocker-B bring-up hack (when
  a hang and a silent gadget were indistinguishable); it is unnecessary now
  and would break OTG host mode. Keep `otg`. If gadget enumeration ever
  regresses, the correct fix is extcon/charger role detection
  (`pmi8950_smbcharger`, `usb_id` GPIO 97), not pinning `peripheral`.

### E-7. Wiki / source findings (via in-app Browser; wiki blocks WebFetch/Anubis)

- **Perry is ARCHIVED** in pmOS ("no longer in pmbootstrap… likely broken…
  build the kernel package manually") — matches our manual r2 carry.
- Perry wiki **feature matrix claims Works**: Flashing, USB-net, Battery,
  **Screen**, Touch, 3D, Audio, WiFi, BT, OTG, accel (Camera broken; modem
  partial). So a mainline kernel HAS driven this hardware — Solution 2
  should get us there.
- Generic **qcom-msm89x7** port lists sibling MSM8917/8937 Motos
  (cedric/montana/hannah/nora) as supported on the SAME kernel+lk2nd — use
  **nora** (also MSM8917) or montana as the "known-good DTS" to diff perry
  against if Blocker B turns out to be a real hang.
- Documented install = `flash_lk2nd` → confirm lk2nd → `flash_rootfs` →
  reset. **lk2nd REQUIRED** (selects panel; without it black screen).
  **No `flash_kernel` needed** (lk2nd boots kernel from the pmOS_boot ext2
  via extlinux). OS image lives at 512 KiB offset in `boot` OR an ext2 fs
  (we use the ext2/extlinux path — supported).

### E-8. Rollback to Lineage (any time, from STOCK fastboot)

`fastboot flash boot ~/android/backups/perry/lineage-boot-2026-07-20.img`
(removes lk2nd) → `fastboot boot ~/android/recovery/twrp-3.7.0_9-0-perry.img`
→ TWRP restore `data` from `twrp-pmos-pre-D-20260720-1656/` (or wipe data
for a clean first boot). `system`/`oem` were never touched by pmOS.
Sacred `persist`/`modemst1`/`modemst2`/`fsg` never in play.

### E-9. Scratchpad artifacts (SESSION-LOCAL — will NOT persist)

lk2nd log dumps and the DTB work-tree lived in the session scratchpad and
are gone next session — but the essential log content and the exact recipe
are captured above, so nothing important is lost. The **patched image on
disk** (`qcom-msm89x7.img`) DOES persist and carries the extlinux `fdt`
fix (+ the DTB fb/usb edits if the write completed — verify by
loop-mounting and checking `extlinux.conf` + `dtc -I dtb` on the perry
DTB's `framebuffer@90001000`/`dr_mode`).

### E-10. USB access + WiFi — WORKING (2026-07-20)

**USB-net / SSH (do this first each session):**
```bash
# find the gadget iface (cdc_ncm, PRODUCT=18d1/d001; lsusb mislabels "Nexus 4")
IFACE=$(for n in /sys/class/net/*; do grep -q cdc_ncm "$n/device/uevent" 2>/dev/null && basename "$n"; done)
sudo ip addr add 172.16.42.2/24 dev "$IFACE"; sudo ip link set "$IFACE" up
ping 172.16.42.1                          # device
ssh xylitol@172.16.42.1                     # key auth; sudo pw xylitol
```
The link **auto-suspends / re-enumerates** (wipes the host IP) — re-add
`172.16.42.2/24` and `timeout`-wrap every ssh before each reconnect.

**WiFi (fixed):** root cause was our DTS pointing `wcn36xx` at
`qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin`, which the rootfs did not
ship → `-2` → no `wlan0`. Installed perry's own NV (`4f88c4c5…`, 31723 B, from
the Lineage build's `vendor/etc/wifi/`) at that path:
```bash
./scripts/pmos-install-wcnss-nv.sh      # idempotent; blob NOT in git (*.bin)
```
Then **reboot** (never manual `remoteproc` restart — it wedges WCNSS SMD):
`sudo sh -c 'sync; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger'`.
Cold boot → `wlan0` up, associates + DHCP, NM auto-reconnects. **Durable fix
DONE:** pmaport `pmos/firmware-motorola-perry-nv/` +
`scripts/pmos-apply-perry-firmware.sh` bakes the NV into the rootfs
(`pmbootstrap build firmware-motorola-perry-nv` →
`install --add firmware-motorola-perry-nv`), surviving `pmbootstrap install`.
Named `-nv` to avoid the archived `firmware-motorola-perry` (wrong
`/lib/firmware/postmarketos/…` path). The APKBUILD **downloads** the blob from
the community mirror pmaports pins (user OK'd outside sources; no blob in git,
no extraction). Mirror NV `3076c1a0…` differs from this unit's stock NV
`4f88c4c5…` (RF/regulatory cal only; MAC is SoC-derived) — device-exact via the
runtime `pmos-install-wcnss-nv.sh` or an aport `source=` override. Build-
validated. See PR [#2](https://github.com/aneesh-pradhan/xylitol/pull/2).
Notes: NV blob stable copy at `~/android/backups/perry/WCNSS_qcom_wlan_nv.perry.bin`;
wcn36xx MAC is device-derived (`02:00:02:4b:07:1b`), not from the NV.

---

## How to start the next session

**Android opener (use this verbatim):**

> Read docs/handoff.md end-to-end and continue perry bring-up. Priority:
> **RIL / mobile network** (or camera AF if continuing — see P1a tradeoff).
> Preview works again after 0015; AF still `Invalid-region`. FM done (0007).
> Stock dump at
> ~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml
> (unpacked under ~/android/stock-perry-NCQS26.69-64-21/). Staging-4.9
> is parked — do not start it unprompted.

**pmOS Ofilm panel research opener (use this verbatim):**

> Read docs/pmos-ofilm-panel.md end-to-end and research the XT1765 Ofilm
> 499 panel gap for postmarketOS. Phases B–D are done; do not flash Phase E
> or edit the kernel overlay unless asked. Deliver the write-up listed in
> §6 of that brief. Downstream MDSS source is in the Lineage msm8953 tree
> (`dsi-panel-mot-ofilm-499-720p-video*.dtsi`). lk2nd getvar dump:
> ~/android/backups/perry/lk2nd-getvar-all.txt.

**pmOS upstream kernel/panel adoption opener (use this verbatim):**

> Read docs/pmos-upstream-kernel-plan.md end-to-end — it's fully
> self-contained. Tracking issue: xylitol#13. This is upstream kernel/DTS/
> panel-driver research and patch-writing against external GitHub repos
> (msm89x7-mainline/linux, msm89x7-mainline/linux-panel-drivers, optionally
> msm8916-mainline/lk2nd) — it does NOT touch the xylitol pmOS build, does
> NOT need pmbootstrap/fastboot, and does NOT need the physical device.
> Re-verify §2's "Verified facts" against live GitHub state before trusting
> any quoted line numbers (things may have moved since 2026-07-21). Work
> §5's roadmap (steps A–F) roughly in order — step A (splitting the rpmcc
> series upstream) is what the fork maintainer gated everything else on.
> §4 has the full line-by-line review-comment checklist; treat it as the
> real acceptance bar. Do not start step F (shrinking xylitol's local
> kernel overlay) until upstream work has actually landed in a tagged
> release, not merely been submitted.

**Agent checklist (Android):**

1. Read this file + porting-log 2026-07-20 camera AF / 0015 regression.
2. Sanity: `qcamerasvr=running`, `dumpsys media.camera` → 2 devices;
   Snap preview + still OK; expect `Invalid-region` again (AF open).
3. Next P1: **RIL** (§1 #3), unless user wants another AF approach.
4. No AI co-author trailers. Sacred: no persist/modemst wipes. Never
   raw-dd sparse `vendor.img`.

**Agent checklist (pmOS panel research):**

1. Read [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) only (self-contained).
2. Answer §3 questions; write §6 deliverable. No flash, no overlay edits.

---

## 0. How we got here (one paragraph)

Boot was blocked by staging-4.9 userspace vs real 3.18 kernel — fixed in
`msm8937-common/0002–0006`. Wi-Fi needed `perry_defconfig` pronto (`kernel/0003`).
Soft navbar: `qemu.hw.mainkeys=0` (`perry/0010`). Camera HAL SEGV was a
missing `camera.msm8937.so` red herring; **0011** montana platform stack
stabilized qcamerasvr. **0012** XT1765 sensors + vendor camera conf →
2 devices (EepromName omitted: montana `eeprom_process` SEGV). Open then
failed on `libactuator_dw9718s_truly.so`; **0013** aliases stock
`dw9718s` under that name → **preview + still capture work** (front+back).
FM needed missing `vendor.fm` + `vendor_fm_app` prop allows (**0007**).
**0014** + kernel **0004** got OTP AF cal working (DAC ranges logged,
`Invalid-region` gone) but stock `sensor_modules` with montana ISP caused
`isp_util_map_streams` **sensor resolution 0x0** → black viewfinder /
"Camera isn't responding". **0015** reverts packaging to montana
`sensor_modules` + omit EepromName; preview restored; AF broken again.
Kernel **0004** (CCI cci0-only) stays — GPIO_31 clash was real.

**Working assumption:** check staging-4.9-isms first; for camera, packaging
before shims. **Do not re-ship stock sensor_modules with montana ISP.**

---

## 1. Open issues — the work queue

### P1 — next session

| # | Issue | State / next step |
|---|---|---|
| 1 | Soft navbar | **FIXED.** |
| 2 | **Camera autofocus** | **OPEN research** — not fixed. Preview/still OK (**0015**). OTP packaging (**0014**) got AF cal working then broke preview (`sensor resolution: 0x0`). Do not re-ship stock `sensor_modules` with montana ISP. Next AF: full stock camera stack, montana `eeprom_process` fix/shim, or actuator `.bin` from OTP DAC ranges. |
| 3 | **Mobile network / RIL** | **PRIORITY** unless continuing AF. Untouched. Stock NCQS26.69-64-21. GSM only; never touch `persist`/`modemst*`. |

### P1a — Camera (post-0015)

**Done**
- **0011:** montana platform stack; qcamerasvr stable.
- **0012:** XT1765 sensors/chromatix/actuator; vendor
  `msm8937_mot_camera_conf.xml`; EepromName omitted (SEGV workaround).
- **0013:** install `libactuator_dw9718s.so` also as
  `libactuator_dw9718s_truly.so` (`device.mk` PRODUCT_COPY_FILES).
- **Kernel 0004:** CCI cci0-only — keep (clears GPIO_31 / sx9310).
- **0014 (historical):** EepromName + stock sensor_modules → OTP AF cal
  worked; **broke preview**.
- **0015:** back to montana sensor_modules; EepromName omitted.

**Live verified (2026-07-20 after 0015 vendor flash)**
- Montana `sensor_modules` MD5 `b57cabd8…` on `/vendor`.
- `dumpsys media.camera`: **2 devices**; Snap `PROFILE_OPEN … rc: 0`.
- Preview path: 960×720; stills `IMG_20260720_1432*.jpg` (~2.5 MB).
- No `resolution: 0x0` / no Snap ANR.
- AF: `Invalid-region size = 0` back (expected).

**OTP DAC ranges captured while 0014 was live (reuse for actuator.bin try)**
- infinity −55..280, macro +61..589, initial code 280
  (`s5k4h8_eeprom_autofocus_calibration`).

**Next AF approaches (do not mix stock sensor_modules + montana ISP)**
1. Full XT1765 stock camera stack (ISP/iface/sensor_modules together).
2. Fix/shim montana `eeprom_process` SEGV with EepromName + montana modules.
3. Ship actuator ringing / region params from known DAC ranges without OTP.

**Packaging**

| Makefile | Role |
|---|---|
| `camera-vendor.mk` | Montana platform including sensor_modules / eeprom_util / pdaf / motocalibration (**0015**) |
| `perry-vendor.mk` | From `proprietary-files.txt` — sensors/chromatix |
| `device.mk` | Camera XMLs + **dw9718s → dw9718s_truly alias (0013)** |

### P2 — after P1 / opportunistic

| # | Issue | State |
|---|---|---|
| 4 | **FM radio** | **FIXED (0007).** User-confirmed (audio + RDS KMVQ-FM). Soft mediametrics denial. |
| 5 | Sepolicy pass | Enforcing; full `audit2allow` after camera AF/RIL/FM. |
| 6 | Hardware audit | BT, audio, sensors, GPS, FP (**egis**), vibrator, LED, SD/OTG, hotspot, MTP. |
| 7 | SystemUI one-off at first boot | Watch only if recurs. |
| 8 | Early-boot cpuset "No space left" | Harmless unless perf issues. |

### P3 — before release / daily-drive

| # | Item |
|---|---|
| 9 | fstab `encryptable=` → `forceencrypt=` |
| 10 | Drop `TARGET_KERNEL_VERSION := 4.9` lie; audit leftover 4.9-isms |
| 11 | Push xylitol; consider forking moto-msm89xx if patches keep growing |
| 12 | TWRP follow-ups (optional) |

---

## 2. Patches (`patches/`)

**perry (17.1 base):** 0001–0009 · **0010** soft navbar · **0011** camera
platform · **0012** XT1765 sensors + vendor camera conf · **0013**
dw9718s_truly alias · **0014** OTP attempt (stock sensor_modules) ·
**0015** keep montana sensor_modules (preview)  
**msm8937-common (18.1):** 0001–0006 · **0007** vendor.fm Iris / FM2  
**kernel msm8953 (18.1):** 0001–0003 · **0004** CCI cci0-only  
Meta: `config/mke2fs.conf`

0015 at perry `9485df8`; 0004 at kernel `7c1b60c`; 0007 at msm8937-common `0a23ebb`.

**Key paths:**

| Item | Path |
|---|---|
| Handoff | `docs/handoff.md` |
| Camera 0011 | `patches/device/motorola/perry/0011-perry-ship-msm8937-camera-platform-stack-from-montana.patch` |
| Camera 0012 | `patches/device/motorola/perry/0012-perry-ship-XT1765-camera-sensors-and-vendor-camera-conf.patch` |
| Camera 0013 | `patches/device/motorola/perry/0013-perry-alias-dw9718s-actuator-as-dw9718s_truly-for-open.patch` |
| Camera 0014 | `patches/device/motorola/perry/0014-perry-restore-EepromName-OTP-with-stock-sensor-modules.patch` |
| Camera 0015 | `patches/device/motorola/perry/0015-perry-keep-montana-sensor_modules-stock-breaks-preview.patch` |
| Kernel 0004 | `patches/kernel/motorola/msm8953/0004-perry-CCI-pinctrl-cci0-only-avoid-GPIO_31-sx9310-clash.patch` |
| FM 0007 | `patches/device/motorola/msm8937-common/0007-msm8937-common-add-vendor.fm-Iris-bring-up-for-FM2.patch` |
| Perry device tree | `~/android/lineage/device/motorola/perry/` |
| Stock unpack | `~/android/stock-perry-NCQS26.69-64-21/` |
| Extract wrapper | `~/GitHub/xylitol/scripts/extract-perry.sh` |
| pmOS WCNSS NV installer | `scripts/pmos-install-wcnss-nv.sh` (blob not in git) |
| pmOS audio UCM pmaport | `pmos/alsa-ucm-motorola-perry/` (APKBUILD + 2 confs) |
| pmOS audio apply (durable) | `scripts/pmos-apply-perry-ucm.sh` |
| pmOS audio install (runtime) | `scripts/pmos-install-perry-ucm.sh` |

---

## 3. Cheat sheet

```bash
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
export PATH="$HOME/android/lineage/prebuilts/python/linux-x86/2.7.5/bin:$PATH"
cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug

m bacon
m vendorimage -j$(nproc)

# CRITICAL: vendor.img is Android SPARSE — never raw-dd it to oem
simg2img out/target/product/perry/vendor.img /tmp/vendor-raw.img
adb reboot recovery
adb push /tmp/vendor-raw.img /sdcard/vendor-raw.img
adb shell 'umount /vendor 2>/dev/null; dd if=/sdcard/vendor-raw.img of=/dev/block/bootdevice/by-name/oem bs=1M; sync'
adb shell 'twrp mount vendor; ls /vendor/lib/libactuator_dw9718s_truly.so /vendor/etc/camera/msm8937_mot_camera_conf.xml'
adb reboot

# Camera triage
adb shell getprop init.svc.vendor.camera-provider-2-5 \
                 init.svc.cameraserver init.svc.vendor.qcamerasvr
adb shell dumpsys media.camera | head -40
adb shell ls -l /sdcard/DCIM/Camera/ | tail
adb logcat -d | grep -iE 'actuator|EEPROM|initializeImpl|CAM_Photo|PROFILE_OPEN|resolution: 0x0'
```

**Sacred:** never wipe/repartition `persist` / `modemst1` / `modemst2`.  
No blobs / `out/` / Lineage tree in xylitol git. No AI co-author trailers.

---

## 4. Stock firmware dump

**Path:** `~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml`  
**Build:** `perry_tmo-user 7.1.1 NCQS26.69-64-21` (reconciled — CLAUDE.md correct).  
**Unpacked:** `~/android/stock-perry-NCQS26.69-64-21/` (`mnt-system` / `tree/system`).

Public notes: [`blobs.md`](blobs.md). Re-unpack:

```bash
./scripts/unpack-stock.sh \
  ~/XT1765_PERRY_TMO_7.1.1_NCQS26.69-64-21_cid21_subsidy-TMO_RSU_regulatory-DEFAULT_CFC.xml
```

---

## 5. Next-agent one-liner

**Android next: RIL** (or AF without stock+montana mix). Preview restored
(0015); AF still `Invalid-region`. FM done (0007).

**pmOS next: BOOTS + WiFi up (Blocker B cleared).** Reachable via
`ssh xylitol@172.16.42.1` (see E-10 for USB-net setup). Next: confirm panel
first-light on screen, walk the feature matrix (BT/audio/sensors/GPS/vibra),
make the WCNSS NV durable as a local pmaport. Ofilm driver 0005/0006,
7.0.9-r2; findings [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md) §7. Never
raw-dd sparse vendor. Sacred: no persist/modemst wipes.

---

## 6. Side quests (do not start unprompted)

- **postmarketOS / mainline:** **ACTIVE — BOOTS.** Phases B–E done. pmOS
  edge (`7.0.9-msm89x7` aarch64) boots to userspace; USB-net + SSH; **WiFi
  working** (`scripts/pmos-install-wcnss-nv.sh`; see E-10 + porting-log
  2026-07-20). Artifacts: `/tmp/postmarketOS-export/`, backups
  `~/android/backups/perry/` (incl. `WCNSS_qcom_wlan_nv.perry.bin`). Lineage
  intact (rollback E-8). **Ofilm 499v0 panel first-light CONFIRMED**
  (user-witnessed; driver 0005/0006, `compatible: motorola,perry-499v0-ofilm`).
  **Open:** remaining feature matrix (BT/audio/sensors/GPS); durable NV
  pmaport; cosmetic initramfs-splash timeout. Brief:
  [`pmos-ofilm-panel.md`](pmos-ofilm-panel.md). Plan/runbook:
  [`pmos-perry.md`](pmos-perry.md), [`pmos-runbook.md`](pmos-runbook.md).
  PR [#48](https://github.com/msm89x7-mainline/linux/pull/48)
  DTS remains the best hardware map for Android HAL/sepolicy too.
- **staging-4.9 kernel port:** [`kernel-4.9-plan.md`](kernel-4.9-plan.md).
  Gate: 18.1 camera AF + RIL done first.
