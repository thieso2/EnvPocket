#!/bin/bash

# Secure Build Script for envpocket
# Builds with security hardening flags

set -e

echo "Building envpocket with security hardening..."

# Security-focused Swift compiler flags
SWIFT_FLAGS=(
    "-Xswiftc" "-enforce-exclusivity=checked"
    "-Xswiftc" "-warn-concurrency"
    "-Xswiftc" "-enable-actor-data-race-checks"
)

# Security-focused linker flags
LINKER_FLAGS=(
    "-Xlinker" "-sectcreate"
    "-Xlinker" "__TEXT"
    "-Xlinker" "__info_plist"
    "-Xlinker" "Info.plist"
)

# Build with hardening
swift build -c release \
    "${SWIFT_FLAGS[@]}" \
    --arch arm64 \
    --arch x86_64

# If you have a Developer ID, sign with entitlements
if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing with entitlements..."
    codesign --force \
        --options runtime \
        --sign "$DEVELOPER_ID" \
        --entitlements EnvPocket.entitlements \
        --timestamp \
        .build/release/envpocket
fi

echo "✅ Secure build complete"

# Verify security settings
echo "Verifying binary security..."
codesign -dvv .build/release/envpocket 2>&1 | grep -E "flags|runtime"

# Check for hardened runtime
if codesign -dvv .build/release/envpocket 2>&1 | grep -q "runtime"; then
    echo "✅ Hardened Runtime enabled"
else
    echo "⚠️  Hardened Runtime not enabled (requires code signing)"
fi