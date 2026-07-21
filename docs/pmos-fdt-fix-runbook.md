# Runbook — validate & make durable the pmOS `fdt` fix (executor)

> **STATUS (2026-07-20): COMPLETE — PASS.** Steps 0–7 executed. apk-regen keeps `fdt`; cold reboot returned on USB-net (uptime 45 s) with `fdt /msm8917-motorola-perry.dtb`. Build up-to-date, no checksum. See porting-log 2026-07-20 "Validate durable fdt fix".


Companion to [`pmos-fdt-brick-fix-plan.md`](pmos-fdt-brick-fix-plan.md) (the
research + rationale). This file is the **step-by-step execution script**. Run
in order. Ordered so the cheap, non-destructive validation **fully proves the
fix before any reboot**, with hard STOP gates where the planning maintainer must
make the call — at a STOP gate, paste the outputs and wait; do not improvise.

**Rules (non-negotiable):** never touch `persist`/`modemst1`/`modemst2`; do
**not** reflash `lk2nd`/`boot` in this task; no blobs/`out/`/Lineage tree into
git; no AI co-author trailers. Device SSH: `aneesh@172.16.42.1`, sudo pw
`147147`. Wrap every ssh in `timeout` (the USB-net link auto-suspends).

---

## Step 0 — Confirm starting files (coordinate with concurrent edits)
```bash
cd ~/GitHub/xylitol
git status --porcelain --untracked-files=all | grep -v '\.bin$'
cat pmos/deviceinfo-motorola-perry/deviceinfo
sha512sum pmos/deviceinfo-motorola-perry/deviceinfo
grep -A2 sha512sums pmos/deviceinfo-motorola-perry/APKBUILD
```
**Expect:** the `deviceinfo` line is `deviceinfo_dtb="qcom/msm8917-motorola-perry"`
and the two sha512 values match. **If they don't match → STOP, report** (the
file changed underneath — do not build a mismatched aport).

## Step 1 — Bring up USB-net
```bash
IFACE=$(for n in /sys/class/net/*; do grep -q cdc_ncm "$n/device/uevent" 2>/dev/null && basename "$n"; done)
sudo ip addr add 172.16.42.2/24 dev "$IFACE" 2>/dev/null; sudo ip link set "$IFACE" up
timeout 8 ping -c2 172.16.42.1
```
**Expect:** replies from `172.16.42.1`. No iface / no reply → power-cycle to a
cold boot and retry. **Still nothing → STOP, report.**

## Step 2 — Capture the BEFORE state (evidence)
```bash
timeout 15 ssh aneesh@172.16.42.1 "grep -E 'fdt|fdtdir' /boot/extlinux/extlinux.conf; echo '---'; ls -l /etc/deviceinfo 2>&1"
```
Record whether it currently says `fdt` or `fdtdir`, and whether `/etc/deviceinfo`
already exists. Either is a valid baseline — just record it.

## Step 3 — Apply the runtime fix
```bash
./scripts/pmos-install-perry-deviceinfo.sh
```
**Expect the tail to print** `fdt /msm8917-motorola-perry.dtb` and **no**
`fdtdir`. **If it prints `fdtdir` → STOP, report** (override didn't take; do not
reboot).

## Step 4 — Assert exactly one dtb resolves
```bash
timeout 20 ssh aneesh@172.16.42.1 'sh -c ". /etc/deviceinfo; c=0; for f in \$deviceinfo_dtb; do c=\$((c+\$(find /boot -path \"/boot/dtbs*/\$f.dtb\" | wc -l))); done; echo dtb_count=\$c; ls -l /boot/msm8917-motorola-perry.dtb"'
```
**Expect:** `dtb_count=1` **and** the flat `/boot/msm8917-motorola-perry.dtb`
exists. **If count ≠ 1 or the flat file is missing → STOP, report** (do not
reboot — the boot line would be wrong/unresolvable).

## Step 5 — Real test: re-trigger the exact regen path that bricked us
```bash
timeout 60 ssh aneesh@172.16.42.1 "echo 147147 | sudo -S -p '' apk add tree >/dev/null 2>&1; echo '--- after apk add ---'; grep -E 'fdt|fdtdir' /boot/extlinux/extlinux.conf; echo 147147 | sudo -S -p '' apk del tree >/dev/null 2>&1"
```
**Expect:** still `fdt /msm8917-motorola-perry.dtb`, **no** `fdtdir`. **If it
flipped back to `fdtdir` → STOP, report** — fix is not durable; do NOT reboot.

## ⛔ STOP GATE — report Steps 3–5 before rebooting
Paste the outputs of Steps 2, 3, 4, 5. Wait for the maintainer's go before the
reboot check. (`fdt` is known-good — it's how Blocker A was cleared — but the
reboot go/no-go is the maintainer's call.)

## Step 6 — (only after go) Reboot confidence check
```bash
timeout 15 ssh aneesh@172.16.42.1 "echo 147147 | sudo -S -p '' sh -c 'sync; echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger'"
```
Wait ~40 s, then repeat Step 1 + ping. **Expect:** device returns on USB-net.
Doesn't return within ~3 min → it's in lk2nd fastboot; recover per
[`handoff.md`](handoff.md) E-8 (Lineage boot rollback) and **report**.

## Step 7 — Durable build-time path
```bash
./scripts/pmos-apply-perry-deviceinfo.sh
pmbootstrap build deviceinfo-motorola-perry
```
**Expect:** clean build (sha512 already matches; no `checksum` step). Durable
install is `pmbootstrap install --add deviceinfo-motorola-perry`. **Do NOT run a
full `pmbootstrap install` reflash in this task** unless told to — just confirm
the build succeeds.

## Step 8 — Report, do NOT commit yet
Summarize: BEFORE state, Steps 3–7 outputs, reboot survival, and whether
`pmbootstrap build` needed a `checksum` step. **Hold all git commits and doc
edits** — the maintainer will hand back the exact commit/doc changes after
reviewing results.
