# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is
`xylitol` is a **meta / patch-and-manifest layer** for porting a LineageOS 18.1 ROM
and a TWRP 3.7.0_9-0 recovery to the Motorola Moto E4 (`perry`, XT1765, msm8937/msm8953).
It contains only Bash scripts (`scripts/`), `repo` local manifests (`manifests/`),
git-format-patch stacks (`patches/`), a CI workflow, and docs. **It is not buildable on
its own** — the actual OS/kernel/TWRP source is fetched at build time by `repo`/`git`
into `~/android/...` (outside the repo) and never committed. Current status and the bug
queue live in `docs/handoff.md`; full chronology in `docs/porting-log.md`.

### Environment setup
`scripts/setup-env.sh` is the canonical host setup (apt build deps, Google `repo` into
`~/bin`, `git-lfs`, `ccache` capped at 25G, and `~/android/mke2fs.conf`). It targets
Ubuntu 26.04 but only *warns* on other versions — it runs fine on the 24.04 cloud image.
It appends `~/bin` to PATH and exports `USE_CCACHE`/`MKE2FS_CONFIG` in `~/.bashrc`/`~/.profile`,
so **a fresh non-login shell won't have `repo` on PATH or `MKE2FS_CONFIG` set** — either
start a login shell, `source ~/.profile ~/.bashrc`, or prepend `export PATH="$HOME/bin:$PATH"`.

### Lint
No dedicated linter is configured. Use `bash -n scripts/*.sh` for syntax and
`xmllint --noout manifests/*.xml` for the manifests. `shellcheck scripts/*.sh` (install via
apt) reports only info-level suggestions today; several (e.g. literal `grep -qF '$HOME/bin'`)
are intentional — do not "fix" them without cause.

### Building / running (heavy — usually out of scope for a quick VM session)
- **ROM:** `scripts/sync.sh` (repo init/sync of the full LineageOS 18.1 tree, then unshallow
  the four perry repos) → `scripts/apply-patches.sh` → `source build/envsetup.sh && lunch
  lineage_perry-userdebug && m bacon` (see the cheat sheet in `docs/handoff.md`). This syncs
  100+ GB and compiles for hours; `MKE2FS_CONFIG=$HOME/android/mke2fs.conf` is required for
  **every** build (host `mke2fs`/apexer breaks otherwise on 24.04+).
- **TWRP:** `scripts/sync-twrp.sh` → `scripts/build-twrp.sh`. Needs **OpenJDK 8** and
  **Python 2.7** (`micromamba create -n py27 -c conda-forge python=2.7`), plus the
  prebuilt-`flex` wrapper that `sync-twrp.sh` installs (Omni 7.1's flex aborts on glibc 2.39+).
  `.github/workflows/twrp.yml` runs this on `ubuntu-22.04` with a 180-min timeout.
- **"Run"** ultimately means flashing to a physical Moto E4 over `fastboot`/`adb`; there is no
  emulator path here, so true functional end-to-end (boot, Wi-Fi, camera, RIL) needs the device.

### Fast smoke test of core functionality (no full build)
The repo's core value is a patch stack that `git am`-applies cleanly onto real upstream. To
verify without a full `repo sync`, shallow-clone just the three patch targets and run the
pipeline against them:
```bash
export PATH="$HOME/bin:$PATH"
T=~/android/hello-tree; mkdir -p "$T/device/motorola" "$T/kernel/motorola"
git clone --depth=1 -b lineage-17.1 https://github.com/moto-msm89xx/android_device_motorola_perry.git          "$T/device/motorola/perry"
git clone --depth=1 -b lineage-18.1 https://github.com/moto-msm89xx/android_device_motorola_msm8937-common.git "$T/device/motorola/msm8937-common"
git clone --depth=1 -b lineage-18.1 https://github.com/moto-msm89xx/android_kernel_motorola_msm8953.git        "$T/kernel/motorola/msm8953"
LINEAGE_DIR="$T" bash scripts/apply-patches.sh   # expect all 18 patches to apply
```

### Gotchas
- `CLAUDE.md` is intentionally listed in `.gitignore`, so docs that link to `../CLAUDE.md`
  point at a file that is not tracked — this is expected, not a missing file.
- Never wipe/repartition `persist` / `modemst1` / `modemst2` on a real device (IMEI/modem).
- `device/motorola/perry` stays on `lineage-17.1` (its `lineage-18.0` branch is a stale decoy);
  the common/kernel/vendor repos are pinned to `lineage-18.1`. See `manifests/perry.xml` comments.
