#!/bin/sh

# This script is used to generate the control file for the Debian package.

# Read the version from the existing control file
VERSION=$(./get-version.sh) || exit 1

echo "Using version: $VERSION"

RAND_BUILD_STR=$(openssl rand -hex 4)

# Write the Info.plist file
defaults write $PWD/Resources/Info.plist CFBundleShortVersionString $VERSION
defaults write $PWD/Resources/Info.plist CFBundleVersion $RAND_BUILD_STR

# Optional CI injection for private-repository update checks (never committed to git)
if [ -n "${UPDATE_GITHUB_TOKEN:-}" ]; then
    ENCODED_UPDATE_TOKEN=$(printf '%s' "$UPDATE_GITHUB_TOKEN" | base64 | tr -d '\r\n')
    defaults write "$PWD/Resources/Info.plist" TSUpdateGitHubTokenBase64 -string "$ENCODED_UPDATE_TOKEN"
else
    defaults delete "$PWD/Resources/Info.plist" TSUpdateGitHubTokenBase64 2>/dev/null || true
fi

TARGET_UPDATE_REPO="${UPDATE_GITHUB_REPO:-${GITHUB_REPOSITORY:-}}"
if [ -n "$TARGET_UPDATE_REPO" ]; then
    defaults write "$PWD/Resources/Info.plist" TSUpdateGitHubRepo -string "$TARGET_UPDATE_REPO"
fi

plutil -convert xml1 $PWD/Resources/Info.plist
chmod 0644 $PWD/Resources/Info.plist

XCODE_PROJ_PBXPROJ=$PWD/BinanceMonitor.xcodeproj/project.pbxproj
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" $XCODE_PROJ_PBXPROJ 2>/dev/null || sed -i "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $VERSION;/g" $XCODE_PROJ_PBXPROJ
