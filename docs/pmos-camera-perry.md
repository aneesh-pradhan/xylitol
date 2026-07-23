# pmOS mainline camera bring-up — perry (MSM8917 / XT1765)

**Status (2026-07-22): front OV5695 ENUMERATES on mainline CAMSS. Capture
(frame delivery) NOT yet working — blocked on `VFE sof timeout` (CSI receive
path). Rear S5K4H8 not started (no mainline driver).**

This is the canonical camera reference. Chronology also in
[`porting-log.md`](porting-log.md) (2026-07-22). Session state in
[`handoff.md`](handoff.md).

---

## TL;DR

- Perry ships **CAMSS + CCI disabled** in the base `msm8917.dtsi`; stock
  `/dev/video0..1` are Venus enc/dec only. Nothing camera exists until DT
  enables it.
- Our carry patch **`pmos/linux-motorola-perry/patches/0007-...`** enables
  `&camss` + `&cci` (cci0 only) and adds the **front OmniVision OV5695**
  sensor node on CCI master 0 / CSIPHY1, plus two gpio-switched fixed
  regulators for the analog/IO rails.
- Kernel config: **`CONFIG_VIDEO_OV5695=m`** (added). `CONFIG_VIDEO_QCOM_CAMSS`
  and `CONFIG_I2C_QCOM_CCI` were already `=m`.
- **The one non-obvious gotcha that cost the most time: perry straps the
  OV5695 i2c slave address to `0x10`, NOT the OmniVision default `0x36`.**
  At 0x36 the sensor returns EIO / id `0x000000`; at 0x10 it reads chip id
  `0x005695`.
- After the fix: `ov5695 2-0010: Detected OV005695 sensor`, a v4l-subdev is
  registered, the media graph links `ov5695 → msm_csiphy1`, and **libcamera
  lists the camera** (`1: 'ov5695' (…/camera@10)`, 2592×1944 = 5 MP).
- **Capture attempt** (`cam --capture`) configures the pipeline (simple
  handler + SoftwareISP, `2592x1944-BGGR-10-CSI2P`) but no frames arrive →
  `qcom-camss: VFE sof timeout` + `VFE reg update timeout`. This is the next
  work item; see **Capture: next steps** below.

---

## Hardware map (perry cameras)

Source: downstream `kernel/motorola/msm8953/arch/arm/boot/dts/qcom/
msm8917-camera-sensor-mot-perry.dtsi` (used as a *hardware map only* — the
proprietary Nougat HAL does not port to pmOS mainline). Confirmed on-device.

| | Rear `camera@0` | Front `camera@1` |
|---|---|---|
| Sensor | **s5k4h8** (Samsung) | **ov5695** (OmniVision, 5 MP) |
| Mainline V4L2 driver | ❌ none | ✅ `drivers/media/i2c/ov5695.c` |
| CSIPHY / CSID | 0 | **1** |
| MCLK | mclk0 = gpio26, 24 MHz | **mclk2 = gpio28, 24 MHz** |
| Reset / standby | standby = gpio35 | **reset = gpio40** (active low) |
| i2c slave addr | (rear, TBD) | **0x10** (NOT 0x36 — verified) |
| VIO 1.8V (dovdd) | pm8937_l6 + gpio27 enable | pm8937_l6 + gpio27 enable |
| VDIG 1.2V (dvdd) | pm8937_l23 | pm8937_l23 |
| VANA 2.8V (avdd) | gpio39 enable | gpio39 enable |
| VAF (AF) | pm8937_l22 (dw9718s) | — (fixed focus) |
| CCI master | 0 | 0 |
| Focus/actuator | AF via **dw9718s** | fixed |

**CCI is master-0 only.** cci0 = gpio29 (SDA) / gpio30 (SCL). cci1 =
gpio31/gpio32 is **unused**: **gpio31 is owned by the `sx9310` SAR sensor**
on the stock board. The downstream DTS says this verbatim ("keep cci0 only so
CCI pinctrl apply does not fail"). Our patch restricts `&cci` pinctrl to
`<&cci0_default>` and disables `&cci_i2c1`.

**Shared rail GPIOs** (both sensors): gpio27 = VIO (1.8V) enable, gpio39 =
VANA (2.8V) enable. gpio35 = rear standby, gpio40 = front reset. These are
external load switches; modelled as `regulator-fixed` in DT.

**Why front first:** the front OV5695 has a mainline driver; the rear S5K4H8
does **not** (and its dw9718**s** actuator has no mainline driver either —
mainline has dw9714/dw9719/dw9768 only). Front is the fast path to first
light. (`imx219` appears in stock libs but is a stock-image artifact, not a
sensor fitted here — the working Android stills came from s5k4h8/ov5695.)

---

## What CAMSS/CCI look like in the base tree

`msm8917.dtsi` (fork `msm89x7-mainline/linux` @ `msm89x7/7.1.3`, the tag the
pmOS kernel builds from) already provides everything, all **`status =
"disabled"`**:

- `camss@1b34000`, compatible `qcom,msm8917-camss` — csiphy0/1, csid0/1/2,
  ispif, vfe0/1; empty `ports { }`.
- `cci@1b0c000`, compatible `qcom,msm8974-cci` — two i2c buses
  `cci_i2c0`/`cci_i2c1`, `assigned-clock-rates = <80000000>, <19200000>`.
- pinctrl states: `camss_mclk0/1/2_default` (gpio26/27/28, function
  `cam_mclk`), `cci0_default` (gpio29/30), `cci1_default` (gpio31/32).

MCLK clock chain: `gcc_camss_mclk2_clk` ← `mclk2_clk_src` ← **`gpll6`**
(1080 MHz) ← xo. The 24 MHz mclk entry is `F(24000000, P_GPLL6, 1, 1, 45)` —
so 24 MHz **requires gpll6** (verified enabling during probe). There is no
XO-based 24 MHz; OV5695 hard-requires 24 MHz.

> **Note:** no other msm8917/msm8937 board enables CAMSS on mainline, so
> perry is the first to exercise the msm8917 camss + gpll6-mclk path. Closest
> structural template is msm8916 `apq8016-sbc-d3-camera-mezzanine.dtso`
> (ov5640 on the same CAMSS generation).

---

## The patch (`0007`)

`pmos/linux-motorola-perry/patches/0007-arm64-dts-qcom-perry-enable-camss-cci-ov5695-front.patch`
appends to `msm8917-motorola-perry-common.dtsi`:

1. **Two fixed regulators** for the gpio-switched rails:
   - `cam_vana_2v8` (avdd, 2.8V) — `gpio = <&tlmm 39>`, enable-active-high.
   - `cam_vio_1v8` (dovdd, 1.8V) — `gpio = <&tlmm 27>`, `vin-supply =
     <&pm8937_l6>`.
   - (dvdd 1.2V = `pm8937_l23` directly, no gpio.)
2. **`&camss`**: `status = "okay"` + `ports/port@1` with `csiphy1_ep`
   (`data-lanes = <0 2>`, remote = `ov5695_ep`).
3. **`&cci`**: `status = "okay"`, `pinctrl-0 = <&cci0_default>` (cci0 only).
4. **`&cci_i2c0`**: `camera@10` node — `compatible = "ovti,ov5695"`,
   `reg = <0x10>`, `clocks = <&gcc GCC_CAMSS_MCLK2_CLK>` name `xvclk` @24 MHz,
   `pinctrl-0 = <&camss_mclk2_default>`, `reset-gpios = <&tlmm 40
   GPIO_ACTIVE_LOW>`, avdd/dovdd/dvdd supplies, endpoint `ov5695_ep`
   (`data-lanes = <1 2>`, `link-frequencies = 420000000`).
5. **`&cci_i2c1`**: `status = "disabled"` (gpio31/sx9310 conflict).

Config: `CONFIG_VIDEO_OV5695=m`.

Authorship: `Aneesh Pradhan <aneeshpradhan@acm.org>` (per the hard rule).

---

## Proof of enumeration (on-device, working)

```
# dmesg
ov5695 2-0010: Detected OV005695 sensor

# nodes: /dev/media0 + video0..7 + v4l-subdev0..14 (was: video0/1 Venus only)

# media graph
- entity: ov5695 2-0010 (1 pad, 1 link)
      -> "msm_csiphy1":0 [ENABLED,IMMUTABLE]
- entity: msm_csiphy1
      <- "ov5695 2-0010":0 [ENABLED,IMMUTABLE]

# libcamera
$ cam -l
Available cameras:
1: 'ov5695' (/base/soc@0/cci@1b0c000/i2c-bus@0/camera@10)
```

This satisfies the **"≥1 sensor enumerates"** half of the done-criterion.

---

## Capture: current blocker + next steps

`cam -c 1 --capture=5` configures the pipeline but no frames arrive:

```
libcamera SimplePipeline: Input 2592x1944-BGGR-10-CSI2P stride 3240
qcom-camss 1b34000.camss: VFE sof timeout
qcom-camss 1b34000.camss: VFE reg update timeout
```

`VFE sof timeout` = the VFE never receives a MIPI Start-of-Frame — the CSI
receive path (sensor → CSIPHY1 → CSID1 → ISPIF → VFE RDI) is not delivering
data. Enumeration is fine; this is pure receive-path bring-up.

Leads, in rough priority order (each = one rebuild/redeploy/re-test cycle):

1. **CSI data-lane mapping.** Current DT: sensor `data-lanes = <1 2>`,
   csiphy1 `data-lanes = <0 2>` (copied from the apq8016 ov5640 template).
   The `<0 2>` on the csiphy side is legacy 8x16 style and may be wrong for
   perry's csiphy1. Try `<1 2>` on both, and/or verify against the OV5695
   driver's 2-lane assumption. **Most likely culprit.**
2. **CAMSS `vdda` supply is a dummy.** dmesg: `qcom-camss: supply vdda not
   found, using dummy regulator` (×3). The camss driver requests a `vdda`
   supply (CSIPHY/CSID analog, `init_load_uA` 9900–80160). It is not wired in
   the base `msm8917.dtsi` camss node. On many boards the dummy is benign
   (rail always-on), but on perry the CSIPHY analog may need a real supply
   (candidate: `pm8937_l2` 1.2V, or the MIPI/CSI rail — check downstream /
   msm8937 camss). Wire `vdda-supply` on `&camss` and re-test.
3. **link-frequency / CSI clock.** OV5695 driver advertises one link freq
   (420 MHz, `OV5695_LINK_FREQ_420MHZ`). Confirm the csid/csiphy accept it;
   check for csid PHY-timer / clock-rate mismatches in dmesg at stream start.
4. **Pipeline link/format setup.** libcamera's `simple` handler auto-links;
   for a manual raw test use `media-ctl` to set matching formats
   (`SBGGR10_1X10`, 2592×1944) on sensor→csiphy1→csid1→ispif→vfe0_rdi0, then
   `v4l2-ctl --stream-mmap` on the RDI `/dev/videoN`. A manual pipeline gives
   cleaner errors than libcamera's SoftwareISP path.

Diagnostic tooling is already installed on-device: `v4l-utils` (media-ctl,
v4l2-ctl), `libcamera-tools` (cam), `i2c-tools` (i2cdetect), plus
`pipewire-spa-libcamera` (Phosh path).

---

## How this was debugged (root-cause method, for reference)

The sensor first probed with `Unexpected sensor id(000000), ret(-5)`. Ruled
out causes methodically over SSH (all via `/sys/kernel/debug`):

1. **Clock** — sampled `gcc_camss_mclk2_clk` during a driver unbind/rebind:
   enable_count hit 1 at 24 MHz, and its source PLL **gpll6** reached
   enable=1 (a first single-sample `gpll6=0` was a read race). Clock path OK.
2. **Power** — made the avdd/dovdd fixed regulators `regulator-always-on`;
   confirmed `enabled` — sensor still id `0x000000`. Power/timing not the
   cause.
3. **Address** — added a temporary driver debug patch (`0008`, since
   reverted) that retried the chip-id read and scanned addresses 0x36 and
   0x10. Result was decisive:
   ```
   camdbg: addr=0x36 try=0..4 ret=-5 id=000000
   camdbg: addr=0x10 try=0 ret=0 id=005695
   Detected OV005695 sensor at 0x10
   ```
   → **the only problem was the i2c address (0x10, not 0x36).** The extended
   settle delay was not needed (detected on the first try at 0x10), and
   `0008` + the always-on rails were reverted for the clean `0007`.

Lesson: on a fresh sensor port, a driver-side "retry + address scan + log the
raw i2c ret" patch is the fastest way to separate *dead bus / wrong address /
wrong power / wrong clock / settle timing*.

---

## Build / deploy / reconnect workflow (fast loop — no fastboot)

Perry boots lk2nd → **extlinux** on the `/boot` partition (vmlinuz +
initramfs + dtb). So kernel/DT changes deploy **in-place over SSH** — no
fastboot, sacred partitions untouched. A bad DT that stops boot is still
recoverable via the fastboot known-good image, and `/boot` was backed up to
`/root/boot-bak-7.1.3-r1` on-device.

```bash
# 1. edit patch/config in pmos/linux-motorola-perry/, then:
./scripts/pmos-apply-kernel-perry.sh          # sync aport -> pmaports
pmbootstrap checksum linux-motorola-perry
pmbootstrap shutdown                           # avoid stale-chroot pre-build zap race
pmbootstrap build linux-motorola-perry --force --lax   # --lax: skip umount-busy zap race

# 2. deploy over SSH (in-place; boot-deploy rewrites /boot):
APK=~/pmos/work/packages/edge/aarch64/linux-motorola-perry-7.1.3-r1.apk
sshpass -p <phone#> scp "$APK" xylitol@172.16.42.1:/tmp/
sshpass -p <phone#> ssh xylitol@172.16.42.1 \
  'echo <phone#> | sudo -S sh -c "apk add --allow-untrusted /tmp/$(basename $APK); reboot"'
#   NB: apk add on a file reinstalls the same version (no --force-reinstall flag in apk).
```

**Reconnect gotchas after a reboot (both bit us this session):**
- The USB gadget MAC **randomizes on full reboot** → new `enx*` name. Re-add
  `172.16.42.2/24` to the *current* `enx*`.
- **Never** put `172.16.42.2/24` on the built-in ethernet `enp42s0` — a
  duplicate /24 there hijacks the route to the phone (silent 100% loss). If
  it happens: `sudo ip addr del 172.16.42.2/24 dev enp42s0`.
- After the MAC change, flush stale neighbors or SSH hangs:
  `sudo ip neigh flush all`.
- SSH password = owner's phone number → see `SECRETS.md` (gitignored).

Build times: full kernel ~4 min warm ccache; DT-only or single-driver
rebuild ~60–70 s. Reboot to sshd ~30 s.

---

## Guardrails (unchanged)

- **Never** ship Android `camera-vendor.mk` / montana ISP blobs on pmOS —
  the proprietary Nougat HAL cannot use mainline CAMSS/V4L2. Android tree is a
  hardware map only.
- Rear S5K4H8 needs a new mainline sensor driver (and dw9718s actuator) —
  much larger; deferred.
- Authorship on every commit/patch: `Aneesh Pradhan <aneeshpradhan@acm.org>`.
- Sacred partitions `persist`/`modemst1`/`modemst2` never touched.
