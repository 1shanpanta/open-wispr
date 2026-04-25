#!/bin/bash
# Local dev rebuild: builds open-wispr, bundles it, signs everything with a
# stable Apple Development identity, and rsyncs into /Applications/OpenWispr.app
# so macOS treats it as the same app across rebuilds (TCC grants survive,
# Launch Services / Spotlight stay calm, Finder customizations on the bundle
# directory persist).
#
# Override the cert by exporting OPENWISPR_SIGNING_IDENTITY before running.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

CERT="${OPENWISPR_SIGNING_IDENTITY:-Apple Development: Ishan Panta (M8456FDZST)}"
BIN=".build/release/open-wispr"
STAGED_APP="OpenWispr.app"
APP_DEST="$HOME/Applications/OpenWispr.app"
VERSION="0.34.0"

if ! security find-identity -v -p codesigning | grep -q "$CERT"; then
    echo "error: signing identity not in keychain: $CERT" >&2
    echo "run 'security find-identity -v -p codesigning' to list available identities" >&2
    exit 1
fi

echo "→ building"
swift build -c release

echo "→ signing binary"
codesign --force --sign "$CERT" --identifier com.ishan.open-wispr "$BIN"

echo "→ bundling"
./scripts/bundle-app.sh "$BIN" "$STAGED_APP" "$VERSION" > /dev/null

echo "→ re-signing bundle with dev cert"
codesign --force --sign "$CERT" --identifier com.ishan.open-wispr --deep "$STAGED_APP"

echo "→ stopping daemon"
pkill -f "$APP_DEST/Contents/MacOS/open-wispr" 2>/dev/null || true
pkill -f "open-wispr start" 2>/dev/null || true
sleep 1

echo "→ syncing to $APP_DEST (preserves xattrs, same inode tree)"
mkdir -p "$APP_DEST"
rsync -a --delete "$STAGED_APP/" "$APP_DEST/"
rm -rf "$STAGED_APP"

echo "→ refreshing Launch Services + Spotlight"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DEST" > /dev/null 2>&1 || true
mdimport "$APP_DEST"

echo "→ launching"
open "$APP_DEST"
sleep 1

if pgrep -f "$APP_DEST/Contents/MacOS/open-wispr" > /dev/null; then
    echo "✓ done — daemon running"
else
    echo "✗ daemon did not start; check ~/.config/open-wispr or run '$APP_DEST/Contents/MacOS/open-wispr' directly"
    exit 1
fi
