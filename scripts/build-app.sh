#!/bin/zsh
# Builds build/Concordance.app.
#   scripts/build-app.sh                 links the model from Vendor/ via ~/Library/Application Support/Concordance/Model
#   scripts/build-app.sh --bundle-model  copies the model into the app (≈1 GB, self-contained, for other Macs)
#   scripts/build-app.sh --run           also (re)launches the app
set -euo pipefail
ROOT="${0:A:h:h}"
MODEL="$ROOT/Vendor/EmbeddingGemma-2-CoreAI/model"
APP="$ROOT/build/Concordance.app"
cd "$ROOT"

[[ -f "$MODEL/config.json" ]] || { echo "Model missing: run scripts/fetch-model.sh first"; exit 1; }

swift build -c release --product Concordance
BIN="$(swift build -c release --show-bin-path)/Concordance"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Concordance"
cp -R "$ROOT/Resources/Fonts" "$APP/Contents/Resources/Fonts"   # Newsreader + iA Writer Mono S (SIL OFL)
cp "$ROOT/Resources/Icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>app.concordance.Concordance</string>
  <key>CFBundleName</key><string>Concordance</string>
  <key>CFBundleDisplayName</key><string>Concordance</string>
  <key>CFBundleExecutable</key><string>Concordance</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Concordance runs commands such as Empty Trash, Toggle Dark Mode and Eject All Disks.</string>
  <key>NSDesktopFolderUsageDescription</key><string>Concordance indexes your Desktop so you can find files and screenshots by what they contain.</string>
  <key>NSDocumentsFolderUsageDescription</key><string>Concordance indexes your Documents so you can find files by what they contain.</string>
  <key>NSDownloadsFolderUsageDescription</key><string>Concordance indexes your Downloads so you can find files by what they contain.</string>
</dict>
</plist>
PLIST

if [[ " $* " == *" --bundle-model "* ]]; then
  ditto "$MODEL" "$APP/Contents/Resources/model"
else
  SUPPORT="$HOME/Library/Application Support/Concordance"
  mkdir -p "$SUPPORT"
  [[ -e "$SUPPORT/Model" && ! -L "$SUPPORT/Model" ]] || ln -sfn "$MODEL" "$SUPPORT/Model"
fi

# A stable signing identity keeps macOS privacy grants (Desktop, Documents…) across rebuilds; ad hoc otherwise.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ { print $2; exit }')"
codesign --force --deep --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed: ${IDENTITY:-ad hoc})"

if [[ " $* " == *" --run "* ]]; then
  pkill -x Concordance 2>/dev/null || true
  open "$APP"
fi
