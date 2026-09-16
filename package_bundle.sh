#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export DEVELOPER_DIR=/Library/Developer/CommandLineTools
INSTALL_NAME_TOOL="/Library/Developer/CommandLineTools/usr/bin/install_name_tool"

echo "==> Building SarvamPlugin in release mode..."
"$DEVELOPER_DIR/usr/bin/swift" build -c release \
  -Xlinker -headerpad_max_install_names \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -Xlinker -rpath -Xlinker /Applications/TypeWhisper.app/Contents/Frameworks

BUNDLE_NAME="SarvamPlugin.bundle"
BUILD_DIR="$SCRIPT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/$BUNDLE_NAME"

echo "==> Assembling $BUNDLE_NAME..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$SCRIPT_DIR/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
cp "$SCRIPT_DIR/Resources/manifest.json" "$BUNDLE_DIR/Contents/Resources/manifest.json"
cp "$SCRIPT_DIR/.build/arm64-apple-macosx/release/libSarvamPlugin.dylib" "$BUNDLE_DIR/Contents/MacOS/SarvamPlugin"

echo "==> Updating library linkage for TypeWhisper host..."
"$INSTALL_NAME_TOOL" -id "@rpath/SarvamPlugin" "$BUNDLE_DIR/Contents/MacOS/SarvamPlugin"
"$INSTALL_NAME_TOOL" -change "@rpath/libTypeWhisperPluginSDK.dylib" "@rpath/TypeWhisperPluginSDK.framework/Versions/A/TypeWhisperPluginSDK" "$BUNDLE_DIR/Contents/MacOS/SarvamPlugin"

echo "==> Code-signing bundle (ad-hoc)..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "==> Verifying signature and bundle structure..."
codesign -vvv "$BUNDLE_DIR"

echo "==> Successfully created $BUNDLE_DIR"

TARGET_PLUGINS_DIR="$HOME/Library/Application Support/TypeWhisper/Plugins"
if [ -d "$TARGET_PLUGINS_DIR" ]; then
    echo "==> Installing into $TARGET_PLUGINS_DIR/$BUNDLE_NAME..."
    rm -rf "$TARGET_PLUGINS_DIR/$BUNDLE_NAME"
    cp -R "$BUNDLE_DIR" "$TARGET_PLUGINS_DIR/"
    echo "==> Installed into TypeWhisper plugins directory!"
fi

echo "==> Packaging shareable archive..."
cd "$BUILD_DIR"
dot_clean "$BUNDLE_NAME"
rm -f "$SCRIPT_DIR/build/SarvamPlugin.zip" "$HOME/Downloads/SarvamPlugin.zip"
zip -r -X -q "$SCRIPT_DIR/build/SarvamPlugin.zip" "$BUNDLE_NAME"
cp "$SCRIPT_DIR/build/SarvamPlugin.zip" "$HOME/Downloads/SarvamPlugin.zip"
echo "==> Clean shareable package updated at ~/Downloads/SarvamPlugin.zip"

