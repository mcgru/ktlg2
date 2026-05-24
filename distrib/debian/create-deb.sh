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

# Source binary path (override for static build, e.g. BINARY=bin/ktlg2.static)
BINARY="${BINARY:-bin/$PACKAGE}"
# Package name suffix in filename (e.g. PKG_SUFFIX=-static -> ktlg2_0.4.0_static_amd64.deb)
PKG_SUFFIX="${PKG_SUFFIX:-}"

DEPS_regular="libexif12, ffmpeg, libpcre2-8-0"
DEPS_static="ffmpeg"
# Автовыбор зависимостей: при статической сборке libexif и pcre2 не нужны
DEPS_VAR="DEPS_${PKG_SUFFIX:-regular}"
DEPS="${!DEPS_VAR}"

# --- check binary exists (built by make deb dependency) ---
if [[ ! -f "$BINARY" ]]; then
  echo "ERROR: $BINARY not found. Run 'make build' first." >&2
  exit 1
fi

# --- prepare package tree ---
PKG_ROOT="$(mktemp -d)"
trap 'rm -rf "$PKG_ROOT"' EXIT

BINDIR="$PKG_ROOT/usr/bin"
DEBIANDIR="$PKG_ROOT/DEBIAN"
mkdir -p "$BINDIR" "$DEBIANDIR"

install -m 0755 "$BINARY" "$BINDIR/$PACKAGE"

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
DEB_FILE="${PACKAGE}_${VERSION}${PKG_SUFFIX:+_${PKG_SUFFIX}}_${ARCH}.deb"
echo "==> Building $DEB_FILE ..."
dpkg-deb --build "$PKG_ROOT" "$DEB_FILE"

echo "==> Done: $DEB_FILE"
