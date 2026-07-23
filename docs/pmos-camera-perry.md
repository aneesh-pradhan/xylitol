# pmOS mainline camera bring-up — perry (MSM8917 / XT1765)

**Status (2026-07-22 night): dual-camera FIRST LIGHT + flash + rear AF.** ✅✅✅

| Subsystem | Status |
|---|---|
| Front OV5695 enumerate | ✅ i2c **0x10**, CSIPHY1 |
| Front OV5695 capture | ✅ ~17.5 fps libcamera; PPM/JPG still |
| Flash/torch (PMI8950) | ✅ rear = `led@0`/`white:flash`, front = `led@1`/`white:flash_1` |
| Rear S5K4H8 enumerate | ✅ i2c **0x2d**, chip id **0x4088**, CSIPHY0 |
| Rear S5K4H8 capture | ✅ **first light** ~24 fps; 3264×2448 GRBG10 |
| Rear AF dw9718s | ✅ `dw9719` / `dongwoon,dw9718s` @ **0x0c**; `focus_absolute` 0↔1023 |

Kernel on glass: `linux-motorola-perry` **7.1.3-r9** (`#10-perry-xylitol`).
Patches **`0007`–`0011`**. Canonical reference for all camera work.
Chronology: [`porting-log.md`](porting-log.md). Session queue:
[`handoff.md`](handoff.md) (local/gitignored).

**Critical external source for rear streaming:** Rockchip vendor
`s5k4h8.c` @ commit `94c738a0…` (scpcom/linux). Local mirror:
[`upstream/s5k4h8-rockchip-ref/`](../upstream/s5k4h8-rockchip-ref/)
(+ gitignored copy under `artifacts/refs/s5k4h8-rockchip-94c738a0/`).

---

## TL;DR

- Perry ships **CAMSS + CCI disabled** in the base `msm8917.dtsi`; stock
  `/dev/video0..1` are Venus enc/dec only until DT enables them.
- **`0007`:** front **OV5695** on CCI0/CSIPHY1 + rails + CAMSS `vdda` +
  CSIPHY lanes `<0 1>`. Config: `CONFIG_VIDEO_OV5695=m`.
- **`0008`:** PMI8950 flash/torch both channels.
- **`0009` + `0010`:** rear **S5K4H8** full V4L2 driver (Rockchip tables,
  mainline CCI) + DT `camera@2d` / CSIPHY0 4-lane / link **280 MHz**.
  Config: `CONFIG_VIDEO_S5K4H8=m`.
- **`0011`:** rear **dw9718s** AF — `CONFIG_VIDEO_DW9719=m`, CCI
  `lens@c` (`dongwoon,dw9718s` @ **0x0c**, `vdd` = `pm8937_l22`),
  `lens-focus` on `camera@2d`. pkgrel **9**.
- **Gotcha #1 (front enumerate):** OV5695 i2c **`0x10`**, not `0x36`.
- **Gotcha #2 (front capture):** need **both** CSIPHY `<0 1>` and real
  `vdda` (`pm8937_l2`).
- **Gotcha #3 (rear enumerate):** 7-bit **0x2d** (stock 8-bit **0x5A**);
  chip id **0x4088**; gpio35 active-low.
- **Gotcha #4 (rear stream on):** mode register `0x0100` is written as
  **8-bit `0x01` / `0x00`** (Rockchip). Writing **16-bit `0x0100` is wrong**.
- **Gotcha #5 (rear libcamera):** pad ops must match the working **ov5695**
  style (`get_fmt`/`set_fmt` + mutex). Using only `v4l2_subdev_get_fmt` +
  unlocked `modify_range` caused **kernel Oops** in `s5k4h8_set_format`.
- **Proof (front):** ~17.5 fps;
  `artifacts/camera-first-light-2026-07-22/ov5695-front-first-light.{ppm,jpg}`.
- **Proof (rear):** `cam -l` lists **both** sensors; capture @ ~24 fps
  3264×2448; artifact
  `artifacts/camera-rear-first-light-2026-07-22/s5k4h8-rear-first-light.jpg`.
- **Proof (AF):** entity `dw9719 2-000c` Lens on `/dev/v4l-subdev16`;
  `focus_absolute` 0↔512↔1023↔0; rear ~24 fps / front ~17.6 fps unchanged.
- **Flash map:** `white:flash` = **rear**, `white:flash_1` = **front**.

---

## Hardware map (perry cameras)

Source: downstream `kernel/motorola/msm8953/arch/arm/boot/dts/qcom/
msm8917-camera-sensor-mot-perry.dtsi` (used as a *hardware map only* — the
proprietary Nougat HAL does not port to pmOS mainline). Confirmed on-device.

| | Rear `camera@0` | Front `camera@1` |
|---|---|---|
| Sensor | **s5k4h8** (Samsung, ~8 MP) | **ov5695** (OmniVision, 5 MP) |
| Mainline V4L2 driver | ✅ `s5k4h8.c` (`0009`, Rockchip tables) | ✅ `drivers/media/i2c/ov5695.c` |
| Bring-up status | ✅ enumerate + capture (~24 fps) + AF | ✅ enumerate + capture |
| CSIPHY / CSID | **0** | **1** |
| Stock CSI lanes | LaneMask `0x1F` → **4-lane** DT | LaneMask `0x07` (2-lane) ✅ |
| MCLK | **mclk0 = gpio26, 24 MHz** | **mclk2 = gpio28, 24 MHz** |
| Reset / standby | **gpio35 active-low** (verified) | **reset = gpio40** (active low) |
| i2c slave (7-bit) | **0x2d** (stock 8-bit **0x5A**) | **0x10** (NOT 0x36 — verified) |
| Chip id | **0x4088** @ reg `0x0000` | **0x005695** |
| Native mode (stock) | **3264×2448** | 2592×1944 |
| EEPROM (OTP) | same 0x5A / 0x2d path (in-sensor) | 0x20 |
| VIO 1.8V (dovdd) | pm8937_l6 + gpio27 enable | pm8937_l6 + gpio27 enable |
| VDIG 1.2V (dvdd) | pm8937_l23 | pm8937_l23 |
| VANA 2.8V (avdd) | gpio39 enable | gpio39 enable |
| VAF (AF) | pm8937_l22 (**dw9718s** @ **0x0c**) | — (fixed focus) |
| CCI master | 0 | 0 |
| Focus/actuator | ✅ **dw9718s** (`dongwoon,dw9718s` via `dw9719.c`; stock 8-bit **0x18**) | fixed |
| Flash LED | PMI8950 `led@0` / `white:flash` | PMI8950 `led@1` / `white:flash_1` |

**CCI is master-0 only.** cci0 = gpio29 (SDA) / gpio30 (SCL). cci1 =
gpio31/gpio32 is **unused**: **gpio31 is owned by the `sx9310` SAR sensor**
on the stock board. The downstream DTS says this verbatim ("keep cci0 only so
CCI pinctrl apply does not fail"). Our patch restricts `&cci` pinctrl to
`<&cci0_default>` and disables `&cci_i2c1`.

**Shared rail GPIOs** (both sensors): gpio27 = VIO (1.8V) enable, gpio39 =
VANA (2.8V) enable. gpio35 = rear standby, gpio40 = front reset. These are
external load switches; modelled as `regulator-fixed` in DT.

**Why front first (historical):** the front OV5695 already had a mainline
driver; rear S5K4H8 needed a port (now done via Rockchip tables). AF is
`dongwoon,dw9718s` on mainline `dw9719.c` (wired in **`0011`**, pkgrel 9).
(`imx219` appears in stock libs but is a stock-image artifact, not a
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

### Rear S5K4H8 ENUMERATE then FIRST LIGHT (2026-07-22 night)

#### Phase A — stock reverse-eng + probe (kernel **7.1.3-r3**)

| Source | Finding |
|---|---|
| `libmmcamera_s5k4h8.so` `.data` | name `s5k4h8`, slave **0x5A** (8-bit write → 7-bit **0x2d**), chip id **0x4088**, MCLK **24 MHz**, mode **3264×2448** |
| `libactuator_dw9718s.so` | `dongwoon` / `dw9718s`, slave **0x18** → 7-bit **0x0c** |
| Downstream DTS | mclk0 gpio26, standby gpio35, CSIPHY0, LaneMask `0x1F`, VAF l22, eeprom 0x5A |

On-device CCI scan after power + mclk0 + gpio35 deassert:

```
s5k4h8 2-002d: cci scan: addr=0x2d reg0000=0x4088
s5k4h8 2-002d: Detected S5K4H8 sensor (id 0x4088)
# 0x0c (AF) ret=-6 with VAF off — expected
```

| Piece | Working value |
|---|---|
| i2c (7-bit) | **0x2d** |
| Chip id | **0x4088** @ `0x0000` |
| Reset / standby | gpio35 **ACTIVE_LOW** |
| MCLK | mclk0 @ 24 MHz |
| CSI | CSIPHY0, CSIPHY `data-lanes = <0 1 2 3>`, sensor `<1 2 3 4>` |
| Rails | shared `cam_vana_2v8` / `cam_vio_1v8` / `pm8937_l23` |

Early `0009` was probe-only (`s_stream` → `-EOPNOTSUPP`). Stock lib tables
alone were incomplete for a clean stream (missing `FCFC` page select pattern,
wrong stream-on width).

#### Phase B — Rockchip driver discovery (the breakthrough)

User found a full GPL-2.0 Rockchip vendor driver:

- **URL:** https://git.servator.de/scpcom/linux/-/blob/94c738a0b0830b0749ef66eb9e7ba6e514f183df/drivers/media/i2c/s5k4h8.c
- **Commit:** `94c738a0b0830b0749ef66eb9e7ba6e514f183df` (scpcom/linux)
- **Author tree copyright:** Fuzhou Rockchip Electronics Co., Ltd. (2017)
- **Local mirrors (do not build Rockchip file as-is on mainline):**
  - **Committed / durable:** [`upstream/s5k4h8-rockchip-ref/`](../upstream/s5k4h8-rockchip-ref/)
    (`s5k4h8.c`, `README.md`, `rk-camera-module.h`, Kconfig/Makefile snippets)
  - **Local only (gitignored):** `artifacts/refs/s5k4h8-rockchip-94c738a0/`

Why it matters:

1. **`s5k4h8_global_regs[]`** — complete TNP firmware load via `0x6028` /
   `0x602A` / `0x6F12`, then trailing sensor setup including **`{0xFCFC, 0x4000}`**
   before the `F4xx` register block (our stock-lib dump had missed `FCFC`).
2. **Mode tables** — `s5k4h8_3264x2448_regs[]` and `s5k4h8_1632x1224_regs[]`
   with documented fps / MIPI rate comments (560 Mbps/lane).
3. **Stream control** — Rockchip writes `0x0100` as **`S5K4H8_REG_VALUE_08BIT`**
   with value **`0x01` (stream) / `0x00` (standby)**. A 16-bit write of
   `0x0100` is incorrect for this sensor.
4. **Controls** — exposure `0x0202`, again `0x0204` (min 32 / max 1024),
   VTS `0x0340`, link freq **280 MHz**, pixel rate **224e6**.
5. **OTP/AWB** — present in Rockchip driver (`s5k4h8_otp_*`, RKMODULE ioctls)
   but **not ported yet** (“otp is not verified” in upstream comment).

What we **deliberately dropped** in the mainline port:

| Rockchip-only | Why dropped |
|---|---|
| `#include <linux/rk-camera-module.h>` | not on mainline |
| `RKMODULE_*` ioctls / module_facing DT props | vendor HAL glue |
| Rockchip pinctrl state names | perry uses qcom pinctrl in DT |
| Direct `i2c_master_send` helpers | use `v4l2-cci` / `cci_write` like s5kjn1 |
| OTP apply path | defer; stock Motorola OTP is a separate research thread |

#### Phase C — mainline port bugs we hit (and fixed)

| Symptom | Root cause | Fix |
|---|---|---|
| libcamera “Unable to get format … Invalid argument” then **Oops** in `s5k4h8_set_format` | pad ops used `v4l2_subdev_get_fmt` / state ACTIVE paths poorly; `ctrl_handler.lock` was **NULL** so `mutex_lock(NULL)` / unlocked `modify_range` crashed | Match **ov5695** pad ops: custom `get_fmt`/`set_fmt` + `struct mutex` as `handler->lock` and `sd.state_lock` |
| No rear in `cam -l` (earlier probe-only) | missing exp/gain/vblank + no stream | full tables + controls |
| Possible silent non-stream | wrong stream-on width | `CCI_REG8(0x0100)` + values 0x01/0x00 |

Kernel progression while iterating: **r3** (probe) → **r4–r7** (broken pad/stream attempts) → **r8** (first light).

#### Phase D — FIRST LIGHT proof (kernel **7.1.3-r8**)

```
$ cam -l
Available cameras:
1: 's5k4h8' (/base/soc@0/cci@1b0c000/i2c-bus@0/camera@2d)
2: 'ov5695' (/base/soc@0/cci@1b0c000/i2c-bus@0/camera@10)

$ cam --camera /base/soc@0/cci@1b0c000/i2c-bus@0/camera@2d --capture=3
# Input 3264x2448-GRBG-10-CSI2P stride 4080
cam0: Capture 3 frames
… seq: 000000 bytesused: 31961088
… seq: 000001 (23.97 fps)
… seq: 000002 (24.03 fps)
# no VFE sof timeout; no Oops
```

Still: `artifacts/camera-rear-first-light-2026-07-22/s5k4h8-rear-first-light.jpg`
(+ `rear.ppm`, ~24 MB). Front regression after rear stream: still ~17.6 fps.

#### DT / package (rear)

| Item | Value |
|---|---|
| Patch `0009` | mainline `s5k4h8.c` — Rockchip tables + CCI + ov5695-style pads |
| Patch `0010` | DT `camera@2d`, mclk0, gpio35, CSIPHY0 4-lane, **link-frequencies = 280000000** |
| Config | `CONFIG_VIDEO_S5K4H8=m` |
| On glass | **7.1.3-r8** |

#### Modes implemented

| Mode | Size | HTS | VTS def | Notes |
|---|---|---|---|---|
| Full | 3264×2448 | 0x0ea0 | 0x09bc | ~25 fps design; ~24 fps observed |
| Bin | 1632×1224 | 0x0ea0 | 0x04e0 | 2×2 binning path from Rockchip table |

Default `cur_mode` prefers full-res. libcamera configures ~3256×2448 ABGR for
SoftwareISP output (sensor still 3264×2448 GRBG10 CSI-2 packed).

### Rear AF dw9718s — DONE (2026-07-22 night, pkgrel **9**)

No new driver. Mainline `dw9719.c` already supports `dongwoon,dw9718s`
(commit `b327384a1349`, Val Packett; SoB André Apitzsch; tested
**motorola-nora**). Perry: config + DT only.

| Item | Value |
|---|---|
| Patch **`0011`** | CCI `lens@c` @ **0x0c**, `vdd-supply = <&pm8937_l22>`, `dongwoon,sac-mode = <4>`; `lens-focus = <&dw9718s>` on `camera@2d` |
| Config | `CONFIG_VIDEO_DW9719=m` |
| On glass | **7.1.3-r9**, uname `#10-perry-xylitol` |
| Entity | `dw9719 2-000c` Lens → `/dev/v4l-subdev16` |
| Proof | `focus_absolute` 0↔512↔1023↔0 OK; rear ~24 fps / front ~17.6 fps (no regression) |

Lore context:
https://lore.kernel.org/phone-devel/20250120-dw9719-v2-0-028cdaa156e5@apitzsch.eu/T/  
Notes: [`upstream/dw9719-mainline-notes/`](../upstream/dw9719-mainline-notes/).  
Tegra historical regs: [`upstream/dw9718-tegra-ref/`](../upstream/dw9718-tegra-ref/).

### Remaining camera work (optional polish)

1. **Phosh / Snapshot** — both cameras via pipewire-spa-libcamera; check
   `50-perry-disable-libcamera.conf`.
2. **libcamera polish** — crop / selection API, rotation, IPA yaml for
   `s5k4h8` / `ov5695`, location properties; AF via libcamera if not yet.
3. **OTP / AWB** — optional later from Rockchip OTP path or Motorola eeprom.
4. **Flash polish** — LED labels; libcamera flash glue.

### Next-session quick commands

```bash
# Both sensors + AF?
dmesg | grep -iE 'ov5695|s5k4h8|dw971|Detected'
cam -l
# expect:
# 1: 's5k4h8' (.../camera@2d)
# 2: 'ov5695' (.../camera@10)
media-ctl -p -d /dev/media0 | grep -A2 dw9719
# Lens entity on /dev/v4l-subdev16 (node may shift)

# AF sweep (adjust -d if subdev number differs)
v4l2-ctl -d /dev/v4l-subdev16 --set-ctrl=focus_absolute=0
v4l2-ctl -d /dev/v4l-subdev16 --set-ctrl=focus_absolute=512
v4l2-ctl -d /dev/v4l-subdev16 --set-ctrl=focus_absolute=1023

# Rear / front capture
cam --camera /base/soc@0/cci@1b0c000/i2c-bus@0/camera@2d --capture=3
cam --camera /base/soc@0/cci@1b0c000/i2c-bus@0/camera@10 --capture=3

# Flash map: L0 rear, L1 front
echo 16 | sudo tee /sys/class/leds/white:flash/brightness; sleep 2
echo 0  | sudo tee /sys/class/leds/white:flash/brightness

# Kernel deploy: apply → checksum → shutdown → build --force --lax → scp apk → reboot
# (see §Build / deploy below)
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
- Dual camera + rear AF first light are done. Remaining camera work is
  optional polish (Phosh, IPA, OTP). Never ship Android montana ISP on pmOS.
- Authorship on every commit/patch: `Aneesh Pradhan <aneeshpradhan@acm.org>`.
- Sacred partitions `persist`/`modemst1`/`modemst2` never touched.
