# Samsung S5K4H8 — mainline media series

**Status (2026-07-23 EOD): series drafted; hold send — more scaffolding needed.**

Still/`cam --capture` works on glass, but **Phosh viewfinder is upside-down
on both cameras** and **extremely laggy/choppy (tearing)**. Treat mainline
mail as blocked on orientation + preview research (handoff §1b), not only on
“user go.”

| Item | State |
|------|--------|
| DT binding | ✅ `samsung,s5k4h8.yaml` — `dt_binding_check` clean |
| Driver | ✅ modern API (`init_state`, `enable_streams`, `v4l2_subdev_init_finalize`) |
| checkpatch --strict | ✅ binding 0e/1w (MAINTAINERS lives in 2/2); driver clean |
| On-device still capture | ✅ pkgrel **15** → `#16-perry-xylitol` rear ~24 / front ~17.6 fps |
| Viewfinder UX | 🔴 upside-down + laggy/tearing (both cams) — needs research |
| format-patch | ✅ `upstream/s5k4h8/patches/` |
| media_tree clone | ⚠ linuxtv.org 502; series based on **torvalds/master** |
| **Mail** | ⛔ hold — orientation/preview + scaffolding first; then user go |

## Series (2 patches)

```
upstream/s5k4h8/patches/
  0000-cover-letter.patch
  0001-dt-bindings-media-i2c-add-Samsung-S5K4H8-image-senso.patch
  0002-media-i2c-add-Samsung-S5K4H8-image-sensor-driver.patch
```

Working branch: `~/src/msm89x7-linux` @ `media-s5k4h8-series`  
(base: torvalds master `4539944e…`; tip has binding + driver commits).

Canonical source tree: `upstream/s5k4h8/s5k4h8.c` + `samsung,s5k4h8.yaml`.

## Goal

Land a mainline V4L2 subdev driver + DT binding for the Samsung **S5K4H8**
so board DTS can use `compatible = "samsung,s5k4h8"` without a local carry.

**Driver-only series.** Perry camera DT nodes stay in pmOS carry until a later
board DTS follow-up.

## Hardware / modes

| Item | Value |
|------|--------|
| Chip id | `0x4088` @ `0x0000` |
| Lanes | 4 |
| MCLK | 24 MHz |
| Link freq | 280 MHz (560 Mbps/lane) |
| Modes | 3264×2448 SGRBG10; 1632×1224 2×2 binning |
| Stream on | **8-bit** `0x01` @ reg `0x0100` |

## Provenance

Register tables from Rockchip vendor `s5k4h8.c` (GPL-2.0, copyright retained).
I/O: mainline `v4l2-cci`. Pad/stream path: modern subdev state API (imx219 /
s5kjn1 style).

## Carry tree (pmOS)

| Patch | Role |
|-------|------|
| `0009` | Full polished+modernized driver (includes former 0013) |
| `0013` | **Merged** into 0009; kept as `.merged-into-0009` |
| `0010` | Rear DT (stay until board DTS upstreamed) |

On glass: `linux-motorola-perry` **7.1.3-r15** / uname `#16-perry-xylitol`.

## Recipients (from get_maintainer)

- Sakari Ailus, Mauro Carvalho Chehab, `linux-media@vger.kernel.org`
- Binding: Rob Herring, Krzysztof Kozlowski, Conor Dooley, `devicetree@vger.kernel.org`
- `linux-kernel@vger.kernel.org`

Re-run after rebase:  
`scripts/get_maintainer.pl 0001-*.patch 0002-*.patch`

## Authorship

```
From: / Signed-off-by: Aneesh Pradhan <aneeshpradhan@acm.org>
```

No AI co-author trailers. Rockchip copyright retained on register tables.

## Before send checklist

1. ✅ On-device retest of final modernized driver
2. ✅ `dt_binding_check DT_SCHEMA_FILES=media/i2c/samsung,s5k4h8.yaml`
3. ✅ checkpatch --strict on both patches
4. ⬜ Optional: rebase onto live `media_tree` master when linuxtv is reachable
5. ⬜ `git send-email --dry-run` eyeball
6. ⬜ **User go** → send to linux-media + DT

## Non-goals (v1)

- OTP / AWB
- Board DTS in this series
- Flash LED V4L2 / dw9718s (already mainline)
