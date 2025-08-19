#!/bin/bash

# Code Signing and Notarization Script for envpocket
# Prerequisites:
# - Apple Developer Account
# - Developer ID Application certificate
# - App-specific password for notarization

set -e

# Configuration (replace with your values)
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
BUNDLE_ID="com.yourcompany.envpocket"
KEYCHAIN_PROFILE="envpocket-notarization"

# Build release version
echo "Building release version..."
swift build -c release

# Sign the binary
echo "Signing binary..."
codesign --force --options runtime --sign "$DEVELOPER_ID" \
    --identifier "$BUNDLE_ID" \
    --timestamp \
    .build/release/envpocket

# Verify signature
echo "Verifying signature..."
codesign --verify --verbose .build/release/envpocket

# Create a zip for notarization
echo "Creating zip for notarization..."
ditto -c -k --keepParent .build/release/envpocket envpocket.zip

# Submit for notarization
echo "Submitting for notarization..."
xcrun notarytool submit envpocket.zip \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# Staple the notarization ticket
echo "Stapling notarization..."
xcrun stapler staple .build/release/envpocket

# Clean up
rm envpocket.zip

echo "✅ Successfully signed and notarized envpocket"