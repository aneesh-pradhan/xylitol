# phosh-plugin-perry-torch

Phosh quick settings for **separate rear and front torch** toggles on perry.

## Status (2026-07-23 pause)

Tiles **appear** in the shade; **clicks do not work** yet. See
`docs/handoff.md` §1a for the debug queue. Sysfs LEDs themselves work.

## Icons

- Plugin list / shade picker: Phosh `torch-enabled-symbolic`, installed as
  `/usr/share/phosh/plugins/icons/perry-{rear,front}-torch-quick-setting-symbolic.svg`
  (`.plugin` `Icon=` = plugin Id, stock naming).
- Runtime tile: theme names `torch-enabled-symbolic` /
  `torch-disabled-symbolic` (shipped in Phosh’s icon gresource).

## Enable

```bash
gsettings set sm.puri.phosh.plugins quick-settings \
  "['perry-rear-torch-quick-setting', 'perry-front-torch-quick-setting']"
# then reboot (preferred) — do not casually pkill phoc (drops to phrog greeter)
```

## LED map

| Sysfs | Plugin |
|---|---|
| `/sys/class/leds/rear:lamp` | Perry Rear Torch |
| `/sys/class/leds/front:lamp` | Perry Front Torch |

Requires `linux-motorola-perry` ≥ 7.1.3-r13 (`rear:lamp` / `front:lamp`).

## API gotcha

Do **not** link against `phosh_quick_setting_set_status_icon()` — it is not
exported from `libphosh`. Attach the status icon via the
`PhoshQuickSetting:status-icon` GObject property (or a GTK Builder template
child named `info`, like stock plugins).
