# Plan — durable fix for the pmOS extlinux `fdt` bricking risk

**Date:** 2026-07-20 · **Status:** research done, ready to execute · **No execution yet.**
**Severity:** SEVERE — the device is one `apk add`/`apk upgrade`/`pmbootstrap
install` + reboot away from unbootable, with **no on-device recovery**.
**Concurrent work:** Cursor is authoring the fix live
(`pmos/deviceinfo-motorola-perry/` + two scripts). This plan **validates** that
work against the real boot-deploy source and defines the execution + test steps.
Owner split: this doc plans; a separate agent executes.

---

## 1. The severe issue (bricking mechanism)

lk2nd boots pmOS via `/boot/extlinux/extlinux.conf` from the ext2 `pmOS_boot`
partition. Any run of `boot-deploy` (triggered by `mkinitfs`, therefore by
**any** `apk add`/`apk upgrade` that touches the kernel/initramfs, and by
`pmbootstrap install`) **regenerates** `extlinux.conf`. With the stock generic
`device-qcom-msm89x7` deviceinfo it regenerates the boot line as:

```
fdtdir /
```

lk2nd cannot resolve `fdtdir /` for perry (perry has **no lk2nd device node**, so
`lk2nd_device_get_dtb_hints()` returns NULL → `"The dtb-files for this device is
not set"` → `Failed to parse extlinux.conf` → falls back to fastboot). Result on
next reboot: **won't boot**, and the only recovery is host-side (loop-mount the
image / re-flash), because you can't reach a shell on the device.

This has already fired twice in real use (Blocker A, and again during the
2026-07-20 feature-matrix walk when `apk add bluez alsa-utils v4l-utils` reset
`extlinux.conf` to `fdtdir /`; it was hand-patched back live). Every hand-patch
is a landmine reset waiting for the next `apk` call.

---

## 2. Root-cause verification (against the real source)

Source of truth: `usr/share/boot-deploy/boot-deploy-functions.sh` **v0.23.0**,
the exact copy installed in `~/pmos/work/chroot_rootfs_qcom-msm89x7/` (dispatched
by `usr/bin/boot-deploy`). Every link in the fix was traced:

| # | Claim | Evidence (line refs) | Result |
|---|---|---|---|
| A | `/etc/deviceinfo` overrides the stock deviceinfo | `boot-deploy` sources `/usr/share/deviceinfo/deviceinfo` **then** `/etc/deviceinfo` (L243, L245); `-c` help (L82) documents `/etc/deviceinfo` as the override slot | ✅ override wins (sourced last) |
| B | stock `deviceinfo_dtb` is a multi-SoC glob → many dtbs → `fdtdir /` | `device-qcom-msm89x7/deviceinfo:21` = `qcom/msm8917-* qcom/msm8937-* …` | ✅ explains the brick |
| C | single dtb ⇒ `fdt`, multi ⇒ `fdtdir` | `create_extlinux_config` L1108–1118: `fdt` iff `find_all_dtbs \| wc -w == 1`, else `fdtdir /` | ✅ pinning one dtb flips it |
| D | emitted `fdt /msm8917-motorola-perry.dtb` path exists in `/boot` | `append_or_copy_dtb` (dispatched L39, before `create_extlinux_config` L44) copies each found dtb **flat** into `/boot` (L410–414) | ✅ path resolves for lk2nd |
| E | pinned stem resolves to exactly one dtb (sibling 8920 does not inflate count) | `find_dtb` exact-name `-path "/boot/dtbs*/qcom/msm8917-motorola-perry.dtb"` (L1383); rootfs has both `msm8917-` and `msm8920-motorola-perry.dtb`, only the exact stem matches | ✅ count == 1 |
| F | the aport actually builds | committed `deviceinfo` sha512 == APKBUILD `sha512sums` | ✅ byte-for-byte match |

**Conclusion:** Cursor's `deviceinfo` override
(`deviceinfo_dtb="qcom/msm8917-motorola-perry"`) is **correct end-to-end** and is
the *sanctioned* pmOS override mechanism — not a hack. Preferred over the
handoff's "RIGHT fix" (perry lk2nd device node) for this specific problem: no
`arm-none-eabi` lk2nd build, **no bootloader reflash**, survives every regen.

---

## 3. What Cursor has produced (live, untracked)

- `pmos/deviceinfo-motorola-perry/deviceinfo` — one override line
  `deviceinfo_dtb="qcom/msm8917-motorola-perry"` (+ rationale comment).
- `pmos/deviceinfo-motorola-perry/APKBUILD` — installs it to `/etc/deviceinfo`;
  `arch="noarch"`, `depends="device-qcom-msm89x7"`, sha512 matches.
- `scripts/pmos-apply-perry-deviceinfo.sh` — copies the aport into the local
  pmaports tree (`device/testing/deviceinfo-motorola-perry`) for
  `pmbootstrap build` / `install --add`.
- `scripts/pmos-install-perry-deviceinfo.sh` — runtime path: writes
  `/etc/deviceinfo` over SSH, re-runs `mkinitfs`, greps `extlinux.conf` for
  `fdt`/`fdtdir`. Never touches persist/modemst*.

All four are sound. The plan below is validation + gap-closing, not rework.

---

## 4. Risks / gaps to close (ordered)

1. **Not auto-pulled into the image.** Nothing `depends` on
   `deviceinfo-motorola-perry`, so a plain `pmbootstrap install` (without
   `--add deviceinfo-motorola-perry`) rebuilds a **vulnerable** rootfs. This is
   the single biggest residual footgun.
   - *Mitigation:* document `--add deviceinfo-motorola-perry` as mandatory in
     the install recipe (pmos.md + handoff), OR fold it into whatever local
     meta/`--add` set the firmware-nv pmaport already uses so the two travel
     together. Do **not** try to edit upstream `device-qcom-msm89x7` depends.
2. **The fix is inert unless the perry dtb is in `/boot/dtbs/qcom/`.** If a
   kernel apk without our r2 overlay is ever installed, `find_all_dtbs` → 0 →
   **no `fdt` line at all** → brick. Add an explicit on-device assertion
   (`find_all_dtbs`-equivalent count == 1) to the runtime installer before it
   claims success.
3. **Out of scope but related — DTB `fb=okay` / `usb=peripheral` edits are also
   lost on every regen** (E-6 items 4/5). The device currently boots without
   them (USB-net + DRM console work post-boot), so this is **not** part of the
   severe fix — but note it so no one assumes this plan makes the boot partition
   fully durable. **RESOLVED 2026-07-20 — RETIRED, no overlay change:** all four
   siblings on this kernel (nora/montana/cedric + perry) ship simplefb
   `disabled` and `dr_mode="otg"`; the device boots with both, so neither hack
   is worth making durable (usb=peripheral would also break OTG host). See
   porting-log 2026-07-20 "Retire Solution-2 DTB hacks". Early splash, if ever
   wanted, = initramfs timeout bump, not simplefb.
4. **lk2nd device node still desirable, separately.** It would fix panel
   auto-select and the cosmetic "Unknown (FIXME!)", and make `fdtdir` work too —
   but it's heavier (lk2nd build + reflash `boot`) and lower urgency. Keep as a
   distinct backlog item, **not** a blocker for shipping this fix.

---

## 5. Execution checklist (for the executor agent)

> Step-by-step runnable version with exact commands, expected outputs, and STOP
> gates: [`pmos-fdt-fix-runbook.md`](pmos-fdt-fix-runbook.md).

Preconditions: pmOS booted, reachable at `ssh xylitol@172.16.42.1` (bring up
USB-net per handoff E-10; sudo pw `xylitol`). Sacred: never touch
`persist`/`modemst1`/`modemst2`; never re-flash lk2nd/`boot` in this task.

**A. Runtime validation (fast, proves the mechanism on the live device):**
1. Run `scripts/pmos-install-perry-deviceinfo.sh` → writes `/etc/deviceinfo`,
   re-runs `mkinitfs`, greps `extlinux.conf`. Expect `fdt
   /msm8917-motorola-perry.dtb`, **no** `fdtdir`.
2. Assert single dtb: on-device, `. /etc/deviceinfo; for f in $deviceinfo_dtb;
   do find /boot -path "/boot/dtbs*/$f.dtb"; done | wc -l` → **1**.
3. **The real test — simulate the trigger that bricks:** `apk add` a small
   throwaway pkg (or `mkinitfs` again) → re-grep `extlinux.conf` → still `fdt`.
   This is the exact regen path that previously reset to `fdtdir`.
4. Confirm `/boot/msm8917-motorola-perry.dtb` (flat) exists.
5. Only after 1–4 pass: reboot and confirm it comes back up (this is the
   destructive confidence check; Lineage rollback in handoff E-8 if needed).

**B. Durable build-time path (survives a fresh `pmbootstrap install`):**
1. `scripts/pmos-apply-perry-deviceinfo.sh` → copies aport into pmaports.
2. `pmbootstrap build deviceinfo-motorola-perry` (sha512 already matches; no
   `checksum` needed unless `deviceinfo` changes).
3. Rebuild/flow: `pmbootstrap install --add deviceinfo-motorola-perry` — and
   **wire `--add` into the standard install recipe** so it is never forgotten
   (gap #1).

**C. Docs (do last, one commit):**
- `docs/handoff.md`: flip to-do #3 (extlinux `fdt`) from URGENT → done; record
  the deviceinfo mechanism + the mandatory `--add`.
- `docs/pmos.md`: add the deviceinfo aport to the reproduction steps.
- `docs/porting-log.md`: dated entry with the §2 verification table.
- Commit style `pmos: …`; **no AI co-author trailers**; blobs/out/tree stay out
  of git.

---

## 6. Coordination note

Since Cursor is editing these same files live, the executor should **re-diff the
four files before acting** (they may have advanced past what §3 describes) and
avoid concurrent writes to `pmos/deviceinfo-motorola-perry/` or the two scripts.
The validation steps in §5A/§5B are independent of further edits Cursor makes,
so they can proceed once Cursor's files settle.
