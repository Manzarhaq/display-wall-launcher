#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/../dist/Display Wall Launcher.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/module-cache"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
for ARCH in arm64 x86_64; do
  swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macosx12.0" \
    -module-name DisplayWallLauncher -module-cache-path "$PWD/.build/module-cache" \
    -framework AppKit -framework WebKit Sources/*.swift -o "$PWD/.build/DisplayWallLauncher-$ARCH"
done
lipo -create .build/DisplayWallLauncher-arm64 .build/DisplayWallLauncher-x86_64 -output "$APP/Contents/MacOS/DisplayWallLauncher"
cp Tests/fixture.html "$APP/Contents/Resources/fixture.html"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DisplayWallLauncher</string>
<key>CFBundleIdentifier</key><string>io.github.displaywalllauncher</string>
<key>CFBundleName</key><string>Display Wall Launcher</string>
<key>CFBundleDisplayName</key><string>Display Wall Launcher</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoadsInWebContent</key><true/></dict>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
cp ../README.md ../LICENSE ../dist/
(cd ../dist && ditto -c -k --keepParent --norsrc 'Display Wall Launcher.app' 'Display-Wall-Launcher-macOS-universal.zip')
# Documentation is alongside the .app inside the download.
python3 - <<'PY'
import zipfile
from pathlib import Path
with zipfile.ZipFile('../dist/Display-Wall-Launcher-macOS-universal.zip','a') as z:
    for name in ['README.md','LICENSE']:
        z.write('../'+name,name)
PY
echo 'Built universal macOS app and ZIP in dist/'
