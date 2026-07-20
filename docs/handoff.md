# Session handoff — perry / xylitol

**Date:** 2026-07-19 (EOD; start next session from here)  
**Meta-repo:** `main` — check `git status` (likely ahead of origin; push when ready)  
**Lineage tree:** `~/android/lineage`  
**Build host:** Ubuntu **26.04** LTS; host e2fsprogs **1.47.2**

Chronology: [`porting-log.md`](porting-log.md). Rules: [`../CLAUDE.md`](../CLAUDE.md).

---

## 1. Phase

| Phase | Status |
|---|---|
| LOS 18.1 ceiling / manifest / sync / env | **Done** |
| Perry device + kernel patches | **Done** (applied in live tree) |
| Full `m bacon` → zip | **Blocked @ ~94%** — see §3 |
| XT1765 proprietary rewrite | **Not done** |
| Boot / SELinux | **Not started** |

**Summary:** Very close to a first zip. Device/Soong blockers fixed. Latest failure is host `mke2fs`/`orphan_file` during ART APEX packaging. A fix is **already in the meta-repo** (`config/mke2fs.conf` + `MKE2FS_CONFIG`); the failed run simply did not have that env var in the build shell.

**Goal:** LineageOS **18.1** for XT1765 perry only.

---

## 2. Do this first next session

```bash
# 1) Ensure the apexer fix is active in THIS shell
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
# confirm no orphan_file:
grep orphan_file "$MKE2FS_CONFIG" || echo 'config OK (no orphan_file)'

# 2) Resume build (do not wipe out/)
cd ~/android/lineage
source build/envsetup.sh && lunch lineage_perry-userdebug
m bacon 2>&1 | tee logs/brunch-perry-$(date +%Y%m%d-%H%M%S).log
```

Optional: `source ~/.bashrc` if the export is already there (setup-env installed it).

Do **not** re-run `apply-patches.sh` unless perry/common/kernel were reset to upstream.

---

## 3. CURRENT blocker

### ART APEX packaging — `orphan_file` (log `172106`)

- **FAILED:** `com.android.art.release.apex.unsigned` via `apexer` → tree `mke2fs` 1.45.4
- **Error:** `Invalid filesystem option set: ... orphan_file`
- **Why:** `/etc/mke2fs.conf` on Ubuntu 26.04 enables `orphan_file`; LOS 18.1 mke2fs cannot use it
- **Fix already landed in xylitol:** commit `9f13fcd`
  - `config/mke2fs.conf` (ext4 features **without** `orphan_file`)
  - copied to `$HOME/android/mke2fs.conf`
  - `scripts/setup-env.sh` + `~/.bashrc` set `export MKE2FS_CONFIG=$HOME/android/mke2fs.conf`
- **Why bacon still failed:** the `172106` job was started in a shell **without** `MKE2FS_CONFIG` set (wrapper did not source bashrc). Re-run with the export.

---

## 4. Fixed earlier this session (cleared)

| Log / stage | Failure | Fix |
|---|---|---|
| extract | Common vendor wiped | git restore + `scripts/extract-perry.sh` |
| makefile | recovery updater / perry filter | `msm8937-common/0001` |
| Soong | dtbtool host rule | `perry/0004` |
| `145405` | OMX V4L2 undeclared macros | `kernel/0002` |
| `154117` | fingerprints HIDL → montana path | `perry/0006` |
| `160541` | `fc_sort` on `file_contexts` | `perry/0007` (trailing newline) |
| sync | `clone-depth="0"` | dropped; sync.sh unshallows |

---

## 5. Still open after zip

1. **Rewrite `proprietary-files.txt`** for XT1765 (montana leftovers; ~26/99 blobs). Reconcile stock build id (`NPNS26.118-22-1` on adb vs `NCQS26.69-64-21` in CLAUDE.md).
2. Boot via `fastboot boot twrp.img`; SELinux denial loop.
3. Push unpushed xylitol commits; keep Cursor co-author off (`attributeCommitsToAgent`).

---

## 6. Patches (`patches/`)

**perry:** 0001 Treble sepolicy/recovery · 0002 BOARD_COMMON · 0003 sepolicy/vendor · 0004 dtbtool Soong · 0005 extract harden · 0006 fingerprints HIDL root · 0007 file_contexts newline  

**msm8937-common:** 0001 Android.mk perry filter  

**kernel msm8953:** 0001 perry_recovery_defconfig · 0002 V4L2 uapi aliases  

Plus meta: `config/mke2fs.conf` for apexer.

---

## 7. Cheat sheet

```bash
export MKE2FS_CONFIG=$HOME/android/mke2fs.conf
cd ~/android/lineage && source build/envsetup.sh && lunch lineage_perry-userdebug && m bacon

bash ~/GitHub/xylitol/scripts/extract-perry.sh adb   # phone in system mode

# if common proprietary wiped:
cd ~/android/lineage/vendor/motorola && git checkout HEAD -- msm8937-common/proprietary/
```

**Sacred:** never wipe `persist` / `modemst1` / `modemst2`. No blobs/`out/` in xylitol.

---

## 8. Next-agent opener

> Read `docs/handoff.md`. Export `MKE2FS_CONFIG=$HOME/android/mke2fs.conf`, resume `m bacon`, confirm zip under `out/target/product/perry/`. If APEX still fails, dig into whether apexer honors `MKE2FS_CONFIG`. Then update handoff/porting-log.
