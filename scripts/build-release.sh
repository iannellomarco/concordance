#!/bin/zsh
# Builds the public release of Concordance: Developer ID signed, notarized, stapled, zipped.
#   scripts/build-release.sh [note]   → dist/Concordance.app, dist/Concordance-<version>.zip
# The app never bundles the ~1 GB model: first launch downloads it from Hugging Face with SHA-256 checks
# (setup assistant, step 1), so the zip stays small.
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

echo "✓ $APP"
echo "✓ $ZIP"
