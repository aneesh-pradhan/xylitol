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

## Wi-Fi NV pmaport (`firmware-motorola-perry-nv`)

The mainline perry DTS points `wcn36xx` at
`qcom/msm8917/motorola/perry/WCNSS_qcom_wlan_nv.bin`; without it Wi-Fi fails
the NV load with `-2` and no `wlan0` appears. pmaports' archived
`firmware-motorola-perry` installs the NV to `/lib/firmware/postmarketos/…`
instead, so it does not satisfy this path. The
[`firmware-motorola-perry-nv/`](firmware-motorola-perry-nv/) aport re-homes the
NV to the DTS path so Wi-Fi survives `pmbootstrap install`.

```bash
./scripts/pmos-apply-perry-firmware.sh
pmbootstrap build   firmware-motorola-perry-nv
pmbootstrap install --add firmware-motorola-perry-nv
```

The APKBUILD **downloads** the blob from the same community perry-firmware
mirror pmaports already pins (verified identical tarball sha512), so nothing
proprietary is committed here. Its NV is a community extract and differs from a
given unit's own stock NV (RF/regulatory cal only) — for a device-exact NV,
see [`../docs/pmos.md`](../docs/pmos.md) step 6.

**Do not** commit proprietary firmware or pmbootstrap chroots into xylitol.

## Extlinux `fdt` pin (`deviceinfo-motorola-perry`)

lk2nd has no perry device node, so the generic `qcom-msm89x7` multi-DTB glob
makes boot-deploy emit `fdtdir /` and boot aborts. This aport installs
`/etc/deviceinfo` pinning `deviceinfo_dtb` to `qcom/msm8917-motorola-perry`,
so every `mkinitfs`/`boot-deploy` run emits
`fdt /msm8917-motorola-perry.dtb`. Verified: survives `apk add` + `mkinitfs`.

```bash
./scripts/pmos-apply-perry-deviceinfo.sh
pmbootstrap checksum deviceinfo-motorola-perry
pmbootstrap build    deviceinfo-motorola-perry
pmbootstrap install  --add deviceinfo-motorola-perry
# live device: ./scripts/pmos-install-perry-deviceinfo.sh
```
