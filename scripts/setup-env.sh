#!/usr/bin/env bash
# Build environment setup for LineageOS 18.1, targeting Ubuntu 26.04 LTS (resolute).
# Package list per wiki.lineageos.org (verified 2026-07-19 against a currently
# supported device's build page, since perry has no wiki page of its own).
set -euo pipefail

GIT_USER_NAME="${GIT_USER_NAME:-aneesh-pradhan}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-zen7370@outlook.com}"
CCACHE_SIZE="${CCACHE_SIZE:-25G}"
BIN_DIR="$HOME/bin"
LINEAGE_DIR="$HOME/android/lineage"

echo "==> Checking OS version"
. /etc/os-release
if [ "${VERSION_ID:-}" != "26.04" ]; then
  echo "Warning: this script targets Ubuntu 26.04 (resolute); detected ${PRETTY_NAME:-unknown}." >&2
fi

echo "==> Installing build packages"
sudo apt-get update
sudo apt-get install -y \
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib git \
  git-lfs gnupg gperf imagemagick protobuf-compiler python3-protobuf \
  lib32readline-dev lib32z1-dev libdw-dev libelf-dev libgnutls28-dev lz4 \
  libsdl1.2-dev libssl-dev libxml2-dev libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc xxd zip zlib1g-dev python-is-python3

# libtinfo5/libncurses5 were dropped from Ubuntu repos after 23.04; LineageOS
# 18.1's prebuilts still need them. Pull the mantic .debs directly.
if ! dpkg -s libtinfo5 >/dev/null 2>&1 || ! dpkg -s libncurses5 >/dev/null 2>&1; then
  echo "==> Installing libtinfo5/libncurses5 from the mantic archive"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  wget -q -P "$tmpdir" \
    https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb \
    https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb
  sudo dpkg -i "$tmpdir"/libtinfo5_6.3-2_amd64.deb "$tmpdir"/libncurses5_6.3-2_amd64.deb
fi

echo "==> Configuring git"
if [ -z "$(git config --global user.email || true)" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi
if [ -z "$(git config --global user.name || true)" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi
git config --global trailer.changeid.key "Change-Id"
git lfs install

echo "==> Setting up directories"
mkdir -p "$BIN_DIR" "$LINEAGE_DIR"

echo "==> Installing repo"
curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$BIN_DIR/repo"
chmod a+x "$BIN_DIR/repo"

if ! grep -qF '$HOME/bin' "$HOME/.profile" 2>/dev/null; then
  cat >> "$HOME/.profile" <<'EOF'

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
EOF
fi

echo "==> Configuring ccache (capped at $CCACHE_SIZE)"
if ! grep -qF 'USE_CCACHE=1' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<EOF

# LineageOS build caching
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
EOF
fi
ccache -M "$CCACHE_SIZE"

# Ubuntu 24.04+ ships e2fsprogs that enable orphan_file in /etc/mke2fs.conf.
# Lineage 18.1's host mke2fs (1.45.x) rejects that feature when apexer builds
# ART APEX images. Install a stripped config and force MKE2FS_CONFIG to it.
META_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MKE2FS_CONF="$HOME/android/mke2fs.conf"
echo "==> Installing Android-compatible mke2fs.conf -> $MKE2FS_CONF"
mkdir -p "$(dirname "$MKE2FS_CONF")"
cp "$META_DIR/config/mke2fs.conf" "$MKE2FS_CONF"
if ! grep -qF 'MKE2FS_CONFIG=' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<EOF

# LineageOS 18.1 apexer + host mke2fs on Ubuntu 24.04+
export MKE2FS_CONFIG=\$HOME/android/mke2fs.conf
EOF
fi

echo "==> Done. Run 'source ~/.profile && source ~/.bashrc' or start a new shell."
