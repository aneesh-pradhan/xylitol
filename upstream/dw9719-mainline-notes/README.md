# Mainline DW9719 / DW9718S (phone-devel series notes)

## Lore thread (user-cited)

- **Thread:** https://lore.kernel.org/phone-devel/20250120-dw9719-v2-0-028cdaa156e5@apitzsch.eu/T/
- **Message-ID pattern:** `20250120-dw9719-v2-0-028cdaa156e5@apitzsch.eu`
- **Author on series:** André Apitzsch `<git@apitzsch.eu>` (v2 cover, 2025-01-20)

> Lore fetch from this agent environment is blocked by Anubis (proof-of-work).
> Content below is reconstructed from **git history that landed** the work.

## What landed (relevant to perry)

In media/mainline (also present on **msm89x7** tag `v7.1.3-r1` that perry
builds from), `drivers/media/i2c/dw9719.c` supports multiple Dongwoon VCMs
including **exactly our part name**:

| Compatible | Model enum | Notes |
|------------|------------|--------|
| `dongwoon,dw9718s` | `DW9718S` | **Perry stock actuator name** |
| `dongwoon,dw9719` | `DW9719` | original |
| `dongwoon,dw9761` | `DW9761` | |
| `dongwoon,dw9800k` | `DW9800K` | later |

Key commit for DW9718S:

```
b327384a1349 media: i2c: dw9719: Add DW9718S support
Author: Val Packett <val@packett.cool>
Signed-off-by: André Apitzsch <git@apitzsch.eu>
…
Tested on the Moto E5 (motorola-nora) smartphone.
```

Related follow-ups in the same driver (power sequence, PM, OF matching):

- `media: i2c: dw9719: Add an of_match_table`
- `media: i2c: dw9719: Add driver_data matching`
- `media: i2c: dw9719: Fix power on/off sequence`
- `media: i2c: dw9719: Update PM last busy time upon close`
- bindings: `Documentation/devicetree/bindings/media/i2c/dongwoon,dw9719.yaml`
  (maintainer: André Apitzsch)

## DW9718S register map in mainline (matches Tegra dw9718.h)

| Reg | Mainline name | Tegra name |
|-----|---------------|------------|
| 0x00 | `DW9718S_PD` | `DW9718_POWER_DN` |
| 0x01 | `DW9718S_CONTROL` | `DW9718_CONTROL` |
| 0x02 | `DW9718S_VCM_CURRENT` (16-bit) | `VCM_CODE_MSB/LSB` |
| 0x04 | `DW9718S_SW` | `SWITCH_MODE` |
| 0x05 | `DW9718S_SACT` | `SACT` |

Position: 0–1023 via `V4L2_CID_FOCUS_ABSOLUTE`.

## Perry implication — do **not** write a new VCM driver

1. Enable `CONFIG_VIDEO_DW9719=m` in perry defconfig.
2. DT on CCI0, e.g.:

```dts
lens@c {
    compatible = "dongwoon,dw9718s";
    reg = <0x0c>;
    vdd-supply = <&pm8937_l22>;
    /* optional: dongwoon,sac-mode = <4>; */
};

/* on rear camera node: */
lens-focus = <&dw9718s>;  /* or however media graph expects */
```

3. Confirm I2C ACK at 0x0c only **after** VAF (`pm8937_l22`) is on.

Tested sibling: **motorola-nora** (Moto E5) — same Dongwoon part family as
XT1765 perry.

## Local files

- `dw9719.c` — snapshot from local msm89x7 tree (includes DW9718S)
- `dongwoon,dw9719.yaml` — DT binding snapshot
- Tegra NVC historical: `../dw9718-tegra-ref/`
- Perry camera doc: `../../docs/pmos-camera-perry.md`
