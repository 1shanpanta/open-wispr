#!/bin/bash
# Local dev rebuild: builds open-wispr, bundles it, signs everything with a
# stable code signing identity, and rsyncs into /Applications/OpenWispr.app
# so macOS treats it as the same app across rebuilds (TCC grants survive,
# Launch Services / Spotlight stay calm, Finder customizations on the bundle
# directory persist).
#
# Choose the identity by exporting SIGN_IDENTITY before running.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

CERT="${SIGN_IDENTITY:-${OPENWISPR_SIGNING_IDENTITY:-}}"
BIN=".build/release/open-wispr"
STAGED_APP="OpenWispr.app"
APP_DEST="$HOME/Applications/OpenWispr.app"
VERSION="0.35.0"

# No certificate name is hard-coded. A single identity in the keychain is used
# as is, and two or more is an error instead of a guess: TCC keys the grant to
# the identity, so signing with the wrong one silently loses every permission.
IDENTITIES="$(security find-identity -v -p codesigning \
    | sed -n 's/^ *[0-9][0-9]*) [0-9A-F]* "\(.*\)"$/\1/p')"
COUNT="$(printf '%s' "$IDENTITIES" | grep -c . || true)"

if [ -z "$CERT" ] && [ "$COUNT" = "1" ]; then
    CERT="$IDENTITIES"
fi

if [ -z "$CERT" ]; then
    if [ "$COUNT" = "0" ]; then
        echo "error: no code signing identity in your keychains" >&2
    else
        echo "error: $COUNT code signing identities found, so pick one:" >&2
        printf '%s\n' "$IDENTITIES" | sed 's/^/    /' >&2
    fi
    echo "  choose one: SIGN_IDENTITY=\"My Identity\" ./scripts/dev-rebuild.sh" >&2
    exit 1
fi

if ! printf '%s\n' "$IDENTITIES" | grep -qxF "$CERT"; then
    echo "error: signing identity not in keychain: $CERT" >&2
    echo "run 'security find-identity -v -p codesigning' to list available identities" >&2
    exit 1
fi

echo "→ signing identity: $CERT"

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
