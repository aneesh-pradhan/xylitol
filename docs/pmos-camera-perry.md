# pmOS mainline camera bring-up — perry (MSM8917 / XT1765)

**Status (2026-07-22 EOD): front OV5695 FIRST LIGHT + PMI8950 flash/torch.** ✅

| Subsystem | Status |
|---|---|
| Front OV5695 enumerate | ✅ i2c **0x10**, CSIPHY1 |
| Front OV5695 capture | ✅ ~17.5 fps libcamera; PPM/JPG still |
| Flash/torch (PMI8950) | ✅ rear = `led@0`/`white:flash`, front = `led@1`/`white:flash_1` |
| Rear S5K4H8 | ❌ no mainline driver — **next** |
| Rear AF dw9718s | ❌ no mainline driver — with rear |

Kernel on glass: `linux-motorola-perry` **7.1.3-r2**. Patches **`0007`**
(camera) + **`0008`** (flash). Canonical reference for all camera work.
Chronology: [`porting-log.md`](porting-log.md). Session queue:
[`handoff.md`](handoff.md) (local/gitignored).

---

## TL;DR

- Perry ships **CAMSS + CCI disabled** in the base `msm8917.dtsi`; stock
  `/dev/video0..1` are Venus enc/dec only until DT enables them.
- **`0007`:** `&camss` + `&cci` (cci0 only) + front **OV5695** on CCI0/CSIPHY1
  + gpio fixed rails + **`vdda-supply = <&pm8937_l2>`** + CSIPHY
  **`data-lanes = <0 1>`**. Config: `CONFIG_VIDEO_OV5695=m`.
- **`0008`:** `&pmi8950_flash` both channels (`leds-qcom-flash-v1`, already
  `CONFIG_LEDS_QCOM_FLASH_V1=m`). Torch-tested channel map below.
- **Gotcha #1 (enumerate):** OV5695 strapped to i2c **`0x10`**, not OmniVision
  default `0x36`.
- **Gotcha #2 (capture):** need **both** CSIPHY `<0 1>` and real `vdda`
  (`pm8937_l2`). `<0 2>` or `<1 2>`-both or dummy vdda → `VFE sof timeout`.
- **Proof:** `cam --camera 1 --capture=5` @ ~17.5 fps; artifact
  `artifacts/camera-first-light-2026-07-22/ov5695-front-first-light.{ppm,jpg}`.
- **Flash map (user-confirmed):** `white:flash` = **rear**, `white:flash_1` =
  **front**.

---

## Hardware map (perry cameras)

Source: downstream `kernel/motorola/msm8953/arch/arm/boot/dts/qcom/
msm8917-camera-sensor-mot-perry.dtsi` (used as a *hardware map only* — the
proprietary Nougat HAL does not port to pmOS mainline). Confirmed on-device.

| | Rear `camera@0` | Front `camera@1` |
|---|---|---|
| Sensor | **s5k4h8** (Samsung, ~8 MP) | **ov5695** (OmniVision, 5 MP) |
| Mainline V4L2 driver | ❌ **none — next work** | ✅ `drivers/media/i2c/ov5695.c` |
| Bring-up status | not started | ✅ enumerate + capture |
| CSIPHY / CSID | **0** | **1** |
| Stock CSI lanes | LaneMask `0x1F` (likely 4-lane) | LaneMask `0x07` (2-lane) ✅ |
| MCLK | mclk0 = gpio26, 24 MHz | **mclk2 = gpio28, 24 MHz** |
| Reset / standby | standby = gpio35 | **reset = gpio40** (active low) |
| i2c slave addr | TBD (scan next) | **0x10** (NOT 0x36 — verified) |
| EEPROM (OTP) | slave **0x5A** | 0x20 |
| VIO 1.8V (dovdd) | pm8937_l6 + gpio27 enable | pm8937_l6 + gpio27 enable |
| VDIG 1.2V (dvdd) | pm8937_l23 | pm8937_l23 |
| VANA 2.8V (avdd) | gpio39 enable | gpio39 enable |
| VAF (AF) | pm8937_l22 (**dw9718s**) | — (fixed focus) |
| CCI master | 0 | 0 |
| Focus/actuator | **dw9718s** (no mainline driver) | fixed |
| Flash LED | PMI8950 `led@0` / `white:flash` | PMI8950 `led@1` / `white:flash_1` |

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

## Capture: FIXED (first light 2026-07-22)

### What worked

After enumeration, `cam --capture` hit `VFE sof timeout` until two DT
changes landed together in patch `0007`:

| DT field | Failed values tried | Working value |
|---|---|---|
| CSIPHY1 `data-lanes` | `<0 2>` (apq8016 mezzanine), `<1 2>` (match sensor) | **`<0 1>`** (0-based physical) |
| Sensor `data-lanes` | — | **`<1 2>`** (unchanged, V4L2 logical) |
| `&camss` `vdda-supply` | *(absent → dummy regulator ×3)* | **`<&pm8937_l2>`** (1.2 V) |

Working capture proof:

```
$ cam --camera 1 --capture=5
… Input 2592x1944-BGGR-10-CSI2P stride 3240
cam0: Capture 5 frames
… seq: 000000 … bytesused: 20404224
… seq: 000001 … (17.52 fps)
… seq: 000002 … (17.60 fps)
… seq: 000003 … (17.69 fps)
… seq: 000004 …
# no VFE sof / reg update timeout in dmesg
```

Still write (PPM via libcamera SoftwareISP path):

```
cam --camera 1 --capture=2 --file=/tmp/camtest/frame.ppm
# → 2584×1944 P6, nonzero_ratio≈0.62, regional color variation (real scene)
```

Artifact on host:
`artifacts/camera-first-light-2026-07-22/ov5695-front-first-light.{ppm,jpg}`.

### Why those two fields

- **Lanes:** qcom-camss builds `lane_mask` from CSIPHY endpoint `data-lanes`
  as *physical positions* (`1 << pos`). Modern mainline boards use 0-based
  consecutive indices on the CSIPHY side (`<0 1>` for 2-lane) and 1-based
  logical on the sensor (`<1 2>`). The apq8016 camera-mezzanine's `<0 2>` is
  board routing for that mezzanine (skip lane 1), not a generic 8x16 rule.
- **vdda:** `csiphy_res_8x39` (msm8917 CAMSS) requests regulator `"vdda"`.
  msm8916-pm8916.dtsi already wires `&camss { vdda-supply = <&pm8916_l2>; }`.
  Perry's `pm8937_l2` is the same 1.2 V class rail (also DSI PHY vdda).

Isolation note: `<1 2>` on both sides alone was **not** enough (still SOF
timeout). The successful boot had **both** `<0 1>` lanes and real `vdda`.

### Flash / torch (PMI8950) — enabled 2026-07-22 night

Front and rear share the **PMI8950** flash LED peripheral (`0xd300`).
Mainline already ships `leds-qcom-flash-v1` + a disabled `pmi8950_flash`
node. Patch **`0008`** enables both channels (montana/hannah/cedric shape).

| | |
|---|---|
| Package | `linux-motorola-perry` **7.1.3-r2** |
| Sysfs | `/sys/class/leds/white:flash` (**rear**), `white:flash_1` (**front**) |
| Map | `led@0` = rear, `led@1` = front (torch test confirmed) |
| Torch | `echo 16 > …/brightness` (max 16); `0` to off |
| Flash | `flash_brightness` + `flash_strobe` (class flash attrs) |
| Note | dummy `flash-boost`/`torch-boost` regulators — same as siblings |

### Remaining camera polish (not blockers for "first light")

1. **Phosh / snapshot UX** — confirm `pipewire-spa-libcamera` / GNOME Snapshot
   opens the front camera (may need udev/seat or disable the temporary
   `50-perry-disable-libcamera.conf` if still present for audio experiments).
2. **libcamera warnings** — missing `ov5695` sensor properties / crop
   rectangles / rotation; optional IPA yaml. Cosmetic for capture.
3. **Exposure / AWB** — SoftwareISP uncalibrated; indoor frames can look dim
   or green-tinted until tuning.
4. **Rear S5K4H8 + dw9718s** — **next north star.** No mainline drivers.
   Start with CCI i2c scan (power + mclk0 + release standby), then new
   V4L2 sensor driver (~1–1.5k LOC scale), then AF VCM (dw9714-family cousins
   exist). Stock: CSIPHY0, likely 4-lane, EEPROM 0x5A, VAF l22.
5. **Flash polish** — optional `label` / `function-enumerator` for
   `white:flash-rear` / `white:flash-front` names; libcamera V4L2 flash glue.
6. **Optional A/B** — isolate first-light: only `vdda` vs only `<0 1>` lanes
   (current tree keeps both).

### Next-session quick commands

```bash
# Front still works?
cam -l
cam --camera 1 --capture=3

# Flash map: L0 rear, L1 front
echo 16 | sudo tee /sys/class/leds/white:flash/brightness; sleep 2
echo 0  | sudo tee /sys/class/leds/white:flash/brightness
echo 16 | sudo tee /sys/class/leds/white:flash_1/brightness; sleep 2
echo 0  | sudo tee /sys/class/leds/white:flash_1/brightness

# Kernel deploy loop (DT/driver): apply → checksum → shutdown → build --force --lax
# → scp apk → apk add → reboot  (see §Build / deploy below)
```

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
