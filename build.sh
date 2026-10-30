#!/bin/sh
set -e
set -o pipefail

# This script is used to build the BinanceMonitor app and create a tipa file with Xcode.

# Read the version from the existing control file
VERSION=$(./get-version.sh) || exit 1

echo "Using version: $VERSION"

# Set GITHUB_WORKSPACE to home directory if not set
if [ -z "$GITHUB_WORKSPACE" ]; then
    GITHUB_WORKSPACE="$HOME"
fi

# Set THEOS to the correct path
THEOS="$GITHUB_WORKSPACE/theos-roothide"
if [ ! -d "$THEOS" ]; then
    THEOS="$GITHUB_WORKSPACE/theos"
fi

# Build using Xcode
xcodebuild clean build archive \
-scheme BinanceMonitor \
-project BinanceMonitor.xcodeproj \
-configuration Release \
-sdk iphoneos \
-destination 'generic/platform=iOS' \
-archivePath BinanceMonitor \
CODE_SIGNING_ALLOWED=NO \
IPHONEOS_DEPLOYMENT_TARGET=16.0 \
THEOS="$THEOS" | xcpretty

chmod 0644 Resources/Info.plist
cp supports/entitlements.plist BinanceMonitor.xcarchive/Products
cd BinanceMonitor.xcarchive/Products/Applications || exit
codesign --remove-signature BinanceMonitor.app
cd - || exit
cd BinanceMonitor.xcarchive/Products || exit
mv Applications Payload
ldid -Sentitlements.plist Payload/BinanceMonitor.app
chmod 0644 Payload/BinanceMonitor.app/Info.plist
zip -qr BinanceMonitor.tipa Payload
cd - || exit
mkdir -p packages
mv BinanceMonitor.xcarchive/Products/BinanceMonitor.tipa packages/BinanceMonitor+AppIntents16_$VERSION.tipa
