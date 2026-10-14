#!/bin/zsh
# Builds the public release of Concordance: Developer ID signed, notarized, stapled; ships a DMG (and a zip).
#   scripts/build-release.sh   → dist/Concordance.app, dist/Concordance-<version>-macOS-arm64.zip,
#                                dist/Concordance-<version>-macOS-arm64.dmg
# The app never bundles the ~1 GB model: first launch downloads it from Hugging Face with SHA-256 checks
# (setup assistant, step 1), so the artifacts stay small.
set -euo pipefail
ROOT="${0:A:h:h}"
APP="$ROOT/dist/Concordance.app"
IDENTITY="0B725CA710AC2B9EF9400B0C56EAD1BCCA7F4770"   # Developer ID Application: Marco Iannello (HX54PKUTV6)
NOTARY_PROFILE="hindsight-notary"

cd "$ROOT"
VERSION="$(defaults read "$ROOT/build/Concordance.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo 0.1.0)"
ZIP="$ROOT/dist/Concordance-${VERSION}-macOS-arm64.zip"

[[ -f "$ROOT/Vendor/EmbeddingGemma-2-CoreAI/model/config.json" ]] \
  || { echo "Model missing: run scripts/fetch-model.sh first (only needed to build; the app downloads its own)."; exit 1; }

echo "→ building Concordance $VERSION"
"$ROOT/scripts/build-app.sh"                       # writes build/Concordance.app (icon, fonts, plist, symlinked model)

echo "→ Developer ID signing (hardened runtime)"
rm -rf "$ROOT/dist" && mkdir -p "$ROOT/dist"
ditto "$ROOT/build/Concordance.app" "$APP"
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"

echo "→ verifying signature"
codesign --verify --deep --strict "$APP" && spctl --assess --type execute -v "$APP" || true

echo "→ zipping for notarization"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "→ notarizing (waits for Apple)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess -v "$APP"

echo "→ re-zipping the stapled app"
rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"

echo "→ building the DMG"
DMG="$ROOT/dist/Concordance-${VERSION}-macOS-arm64.dmg"
BG="$ROOT/dist/.dmg-staging/.background/background.png"
rm -rf "$ROOT/dist/.dmg-staging"
mkdir -p "$ROOT/dist/.dmg-staging/.background"
swift "$ROOT/scripts/render-dmg-background.swift" "$BG"
ln -s /Applications "$ROOT/dist/.dmg-staging/Applications"
cp -R "$APP" "$ROOT/dist/.dmg-staging/Concordance.app"
rm -f "$DMG" "$ROOT/dist/.dmg-rw.dmg"
# The layout (window bounds, background, icon positions) lives in the volume's .DS_Store, which Finder can only
# write on a READ-WRITE image. So: create UDRW → script the layout (Finder persists .DS_Store) → convert to UDBZ.
hdiutil create -volname "Concordance" -srcfolder "$ROOT/dist/.dmg-staging" -ov -format UDRW "$ROOT/dist/.dmg-rw.dmg" >/dev/null
hdiutil attach "$ROOT/dist/.dmg-rw.dmg" -mountpoint "/Volumes/ConcordanceRW" -nobrowse >/dev/null
# macOS 27 Finder: `update` and closed-window `toolbar visible` are gone; keep the window open while scripting
# and reference the background via the mounted volume's POSIX path.
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "ConcordanceRW"
    open
    delay 1
    set current view of container window to icon view
    set bounds of container window to {0, 0, 720, 420}
    set theOptions to icon view options of container window
    set arrangement of theOptions to not arranged
    set icon size of theOptions to 128
    set background picture of theOptions to (POSIX file "/Volumes/ConcordanceRW/.background/background.png" as alias)
    set position of item "Concordance" of container window to {190, 175}
    set position of item "Applications" of container window to {530, 175}
  end tell
end tell
APPLESCRIPT
sleep 3   # let Finder flush the .DS_Store
[[ -f /Volumes/ConcordanceRW/.DS_Store ]] || { echo "Finder did not write .DS_Store; DMG would open unstyled"; exit 1; }
hdiutil detach "/Volumes/ConcordanceRW" >/dev/null
sleep 1
hdiutil convert "$ROOT/dist/.dmg-rw.dmg" -format UDBZ -o "$DMG" >/dev/null
rm -f "$ROOT/dist/.dmg-rw.dmg"

echo "→ notarizing the DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
rm -rf "$ROOT/dist/.dmg-staging"

echo "✓ $APP"
echo "✓ $ZIP"
echo "✓ $DMG"
