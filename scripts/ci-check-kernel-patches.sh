#!/usr/bin/env bash
# CI + local check: verify every linux-motorola-perry patch still applies
# cleanly against the exact upstream kernel tag pinned in the APKBUILD.
#
# This is the check that silently breaks on a kernel rebase: bump the tag,
# forget to re-roll a patch, and the next image build fails deep in a chroot.
# Running it here (and in CI) turns that into a fast, obvious red X.
#
# Usage: ./scripts/ci-check-kernel-patches.sh
# Exit 0 = all patches apply; non-zero = at least one fails (details printed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKGDIR="$ROOT/pmos/linux-motorola-perry"
APKBUILD="$PKGDIR/APKBUILD"
PATCHDIR="$PKGDIR/patches"

[ -f "$APKBUILD" ] || { echo "ERROR: $APKBUILD not found" >&2; exit 2; }

# Pull the pinned coordinates straight from the APKBUILD (no sourcing).
val() { grep -E "^$1=" "$APKBUILD" | head -1 | cut -d= -f2- | tr -d '"'; }
pkgver="$(val pkgver)"
srcrel="$(val _srcrel)"
url="$(val url)"
: "${pkgver:?missing pkgver}" "${srcrel:?missing _srcrel}" "${url:?missing url}"
tag="v${pkgver}-r${srcrel}"
tarball_url="${url}/archive/${tag}.tar.gz"

echo "==> pinned kernel: $tag"
echo "==> source:        $tarball_url"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> downloading tarball..."
curl -fsSL -o "$WORK/src.tar.gz" "$tarball_url"

echo "==> extracting..."
tar -C "$WORK" -xzf "$WORK/src.tar.gz"
tree="$(find "$WORK" -maxdepth 1 -type d -name 'linux-*' | head -1)"
[ -n "$tree" ] || { echo "ERROR: extracted kernel dir not found" >&2; exit 2; }

cd "$tree"
git init -q
git config user.email ci@local
git config user.name ci
git add -A
git commit -qm baseline

echo
echo "==> test-applying patches from $PATCHDIR"
fail=0
shopt -s nullglob
patches=("$PATCHDIR"/[0-9][0-9][0-9][0-9]-*.patch)
[ "${#patches[@]}" -gt 0 ] || { echo "ERROR: no patches found" >&2; exit 2; }
for f in "${patches[@]}"; do
  name="$(basename "$f")"
  if git apply --check "$f" 2>/tmp/ci-ga.err; then
    echo "  OK    $name"
    git apply "$f"; git add -A; git commit -qm "$name"
  else
    echo "  FAIL  $name"
    sed 's/^/          /' /tmp/ci-ga.err | head -12
    fail=1
    # keep stacking the rest against the last good state to report all failures
  fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: one or more patches DO NOT apply against $tag" >&2
  exit 1
fi
echo "RESULT: all ${#patches[@]} patches apply cleanly against $tag"
