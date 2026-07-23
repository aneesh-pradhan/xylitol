# Reference: NVIDIA Tegra DW9718 VCM / focuser driver

**Source tree:** `kernel/tegra` @ `2268683075e741190919217a72fcf13eb174dc57`  
**Path:** `drivers/media/platform/tegra/dw9718.c`  
**URL:** https://android.googlesource.com/kernel/tegra/+/2268683075e741190919217a72fcf13eb174dc57/drivers/media/platform/tegra/dw9718.c  
**Fetched:** 2026-07-22 (perry rear AF bring-up)

## License / copyright

- GPL-2.0
- Copyright (C) 2013, NVIDIA CORPORATION. All rights reserved.

## Why we keep this

Perry rear AF is **Dongwoon dw9718s** (stock `libactuator_dw9718s.so`,
8-bit slave **0x18** → 7-bit **0x0c**, VAF `pm8937_l22`).

**Superseded as the port plan:** mainline / msm89x7 `dw9719.c` already
supports compatible **`dongwoon,dw9718s`** (see
[`../dw9719-mainline-notes/`](../dw9719-mainline-notes/)). Perry AF work
is config + DT, not a new driver.

This Tegra NVC focuser remains useful as a **register / DAC reference**
(platform/NVC style, not modern V4L2 VCM):

- Register map / programming sequence for the DW9718 family
- Power / GPIO / I2C write patterns
- Position / DAC limits and mode bits

**Not a drop-in** for mainline CAMSS/libcamera.

## Perry hardware map (AF)

| Item | Value |
|------|--------|
| Chip | dw9718**s** (stock name; “s” suffix may be module variant) |
| I2C | CCI master 0; 7-bit **0x0c** (stock 8-bit **0x18**) |
| VAF supply | `pm8937_l22` (2.8 V) |
| Sensor | rear S5K4H8 (already first-light) |
| Mainline cousins | `dw9714.c`, `dw9719.c`, `dw9768.c` |

On enumerate-era CCI scan with VAF off, `0x0c` returned `-6` (no ACK) —
expected until the AF rail is enabled.

## Register map (from `dw9718.h`)

| Reg | Name | Role |
|-----|------|------|
| 0x00 | `DW9718_POWER_DN` | Power-down (write 0x01 then 0x00 in init) |
| 0x01 | `DW9718_CONTROL` | Control / slew high byte path |
| 0x02 | `DW9718_VCM_CODE_MSB` | Position (driver writes 16-bit code here) |
| 0x03 | `DW9718_VCM_CODE_LSB` | Position low (paired with MSB) |
| 0x04 | `DW9718_SWITCH_MODE` | Mode switch |
| 0x05 | `DW9718_SACT` | SAC / active control (slew low byte) |
| 0x06 | `DW9718_STATUS` | Status |

### Programming notes from `dw9718.c`

- Position clamp: **0x03ff** (10-bit DAC, 0–1023) — same range as mainline dw9714.
- Tegra defaults: infinity **70**, macro **620**, settle **30** ms, slew **0x0060**.
- `dw9718_position_wr()` → `dw9718_i2c_wr16(info, DW9718_VCM_CODE_MSB, position)`.
- Init pulses `POWER_DN` 0x01 → 0x00, programs CONTROL + SACT from slew rate.
- Uses NVIDIA NVC MISC `/dev/focuser*` ABI — not V4L2 `V4L2_CID_FOCUS_ABSOLUTE`.

### Contrast with mainline `dw9714`

| | Tegra dw9718 | Mainline dw9714 |
|--|--------------|-----------------|
| ABI | NVC misc focuser | V4L2 subdev VCM |
| I2C framing | 8-bit reg + data | 16-bit big-endian word (code≪4 \| step) |
| Max pos | 1023 | 1023 |
| Compatible | board pdata | `dongwoon,dw9714` |

**Update (2026-07-22):** Mainline **`dw9719.c` already supports
`dongwoon,dw9718s`** (same register layout). Prefer enabling that driver + DT
over writing a new VCM. See `../dw9719-mainline-notes/` and lore series
https://lore.kernel.org/phone-devel/20250120-dw9719-v2-0-028cdaa156e5@apitzsch.eu/T/

This Tegra file remains useful for historical NVC sequences / slew defaults.
Stock infinity/macro calibration may still need device OTP
(`s5k4h8_eeprom_autofocus_calibration` in porting-log).

## Related local refs

- S5K4H8 Rockchip sensor: `upstream/s5k4h8-rockchip-ref/`
- Datasheet (if present): `docs/DW9718S.pdf`
- Camera bring-up: `docs/pmos-camera-perry.md`

## Files

| File | Role |
|------|------|
| `dw9718.c` | Full Tegra NVC focuser driver (1132 LOC) |
| `dw9718.h` | Register map + platform_data |
| `nvc_focus.h` / `nvc.h` | NVIDIA NVC headers this driver needs |
