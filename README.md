# xylitol
Custom kernel + OS for the Moto E4 (perry)

**Handoff / current phase:** see [`docs/handoff.md`](docs/handoff.md)  
**Chronology:** [`docs/porting-log.md`](docs/porting-log.md)

## Blob extraction (important)

`device/motorola/perry/extract-files.sh` delegates to msm8937-common, which
defaults to **wiping** `vendor/motorola/msm8937-common/proprietary/` before
extract (`CLEAN_VENDOR=true`). A bare `./extract-files.sh adb` will destroy
the committed common vendor APKs.

For perry-only refreshes use:

```bash
./scripts/extract-perry.sh adb
# equivalent:
cd ~/android/lineage/device/motorola/perry && ./extract-files.sh -n --only-target adb
```

If common was wiped accidentally:

```bash
cd ~/android/lineage/vendor/motorola && git checkout HEAD -- msm8937-common/proprietary/
```
