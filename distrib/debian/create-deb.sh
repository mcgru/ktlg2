#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

# --- config ---
PACKAGE="ktlg2"
VERSION="${VERSION:-$(awk '/^version:/ {print $2}' shard.yml)}"
ARCH="amd64"
MAINTAINER="${MAINTAINER:-ktlg2 maintainer <ktlg2@example.com>}"
DESCRIPTION="Media file cataloging utility
 Organize, rename, touch, check and deduplicate media files
 (JPEG, PNG, MP4, AVI, MOV)."

DEPS="libexif12, ffmpeg, libpcre2-8-0"

# --- build release binary ---
echo "==> Building release binary..."
crystal build src/main.cr --release -o "bin/$PACKAGE"

# --- prepare package tree ---
PKG_ROOT="$(mktemp -d)"
trap 'rm -rf "$PKG_ROOT"' EXIT

BINDIR="$PKG_ROOT/usr/bin"
DEBIANDIR="$PKG_ROOT/DEBIAN"
mkdir -p "$BINDIR" "$DEBIANDIR"

install -m 0755 "bin/$PACKAGE" "$BINDIR/$PACKAGE"

# --- control file ---
cat > "$DEBIANDIR/control" <<EOF
Package: $PACKAGE
Version: $VERSION
Architecture: $ARCH
Maintainer: $MAINTAINER
Depends: $DEPS
Section: utils
Priority: optional
Description: $DESCRIPTION
EOF

# --- build .deb ---
DEB_FILE="${PACKAGE}_${VERSION}_${ARCH}.deb"
echo "==> Building $DEB_FILE ..."
dpkg-deb --build "$PKG_ROOT" "$DEB_FILE"

echo "==> Done: $DEB_FILE"
