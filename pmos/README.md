# postmarketOS local overlays (perry)

Host workdir (outside this repo): `~/pmos/`  
pmbootstrap: `~/pmos/pmbootstrap` (symlink `~/bin/pmbootstrap`)  
pmaports / chroots: `~/pmos/work/`

## Kernel carry (`linux-postmarketos-qcom-msm89x7`)

Packaged edge kernel **does not** ship `msm8917-motorola-perry.dtb`. This
overlay carries:

| Patch | Source |
|---|---|
| 0001–0003 | [msm89x7-mainline/linux#48](https://github.com/msm89x7-mainline/linux/pull/48) (rebased to `v7.0.9-r0`; Makefile typo fixed) |
| 0004 | Tianma 499v1 panel from [linux-panel-drivers#6](https://github.com/msm89x7-mainline/linux-panel-drivers/pull/6) (`motorola,perry-499v1-tianma`), generated with `lmdpdg --dumb-dcs` |
| 0005 | **Ofilm 499v0 panel driver** (`motorola,perry-499v0-ofilm`) — this XT1765's actual panel |
| 0006 | DTS: select the Ofilm 499v0 panel |

**Panel (2026-07-20): first-light CONFIRMED.** This XT1765 is **Ofilm**
(`lk2nd:panel:qcom,mdss_dsi_mot_ofilm_499_720p_video_v0`), not Tianma — 0005
adds the driver and 0006 selects it. Verified rendering on the booted rootfs
(user-witnessed framebuffer + backlight). If your unit is a different variant
(Tianma/BOE/INX), change the `compatible` selected in 0006. Panel notes:
[`../docs/pmos-ofilm-panel.md`](../docs/pmos-ofilm-panel.md); reproduction:
[`../docs/pmos.md`](../docs/pmos.md).

Apply into the live pmaports tree:

```bash
./scripts/pmos-apply-perry-kernel.sh
pmbootstrap checksum linux-postmarketos-qcom-msm89x7
pmbootstrap build linux-postmarketos-qcom-msm89x7
```

Expected artifact: `/boot/dtbs/qcom/msm8917-motorola-perry.dtb` inside the
built package.

**Do not** commit proprietary firmware or pmbootstrap chroots into xylitol.
