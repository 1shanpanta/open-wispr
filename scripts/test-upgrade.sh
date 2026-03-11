#!/bin/bash
set -euo pipefail

echo "==> Stopping any running instances..."
pkill -f "open-wispr start" 2>/dev/null || true
brew services stop open-wispr 2>/dev/null || true
sleep 1

echo "==> Building from source..."
swift build -c release 2>&1 | tail -1

echo "==> Bundling app..."
bash scripts/bundle-app.sh .build/release/open-wispr OpenWispr.app dev
rm -rf ~/Applications/OpenWispr.app
cp -R OpenWispr.app ~/Applications/OpenWispr.app
rm -rf OpenWispr.app

echo ""
echo "==> Manual step required:"
echo "   1. Open System Settings > Privacy & Security > Accessibility"
echo "   2. Select OpenWispr and click the MINUS button to remove it"
echo "   3. Press Enter here to continue"
echo ""
read -r -p "Press Enter after removing OpenWispr from Accessibility..."

echo ""
echo "==> Starting open-wispr..."
echo "   After 10 seconds the menu bar should show the re-add hint."
echo ""
~/Applications/OpenWispr.app/Contents/MacOS/open-wispr start
