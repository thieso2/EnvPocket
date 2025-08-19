# Security Hardening Guide for envpocket

This guide explains how to build and distribute envpocket with enhanced security features.

## Overview

While macOS command-line tools cannot use App Sandbox (which is designed for GUI applications), we can still implement several security measures:

1. **Code Signing** - Cryptographically sign the binary
2. **Notarization** - Apple's malware scanning service  
3. **Hardened Runtime** - Runtime security protections
4. **Entitlements** - Declare and limit capabilities
5. **Keychain Access Groups** - Team-based isolation

## Important Limitations

- **No App Sandbox**: Command-line tools cannot use macOS App Sandbox as it's designed for apps with GUI
- **No Provisioning Profiles**: These are for iOS/macOS apps, not CLI tools
- **Keychain Access**: CLI tools need full keychain access to function (cannot be restricted like sandboxed apps)

## Implementation Steps

### 1. Basic Security (No Developer Account Required)

Use the secure build script for compiler-level hardening:

```bash
./Scripts/build-secure.sh
```

This enables:
- Memory safety checks
- Concurrency warnings
- Data race detection
- Universal binary (arm64 + x86_64)

### 2. Code Signing (Requires Apple Developer ID)

Prerequisites:
- Apple Developer Account ($99/year)
- Developer ID Application certificate

Sign the binary:
```bash
codesign --force --options runtime \
    --sign "Developer ID Application: Your Name (TEAMID)" \
    --entitlements EnvPocket.entitlements \
    --timestamp \
    .build/release/envpocket
```

### 3. Notarization (Requires Developer Account)

After signing, submit to Apple for notarization:

```bash
# Store credentials (one-time setup)
xcrun notarytool store-credentials "envpocket-notarization" \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "app-specific-password"

# Run the notarization script
./Scripts/sign-and-notarize.sh
```

### 4. Verification

Verify the security features:

```bash
# Check code signature
codesign -dvv .build/release/envpocket

# Check entitlements
codesign -d --entitlements - .build/release/envpocket

# Check notarization
spctl -a -vvv -t install .build/release/envpocket
```

## Security Features by Implementation Level

### Level 1: Basic (Current Implementation)
- ✅ Namespace isolation (envpocket: prefix)
- ✅ No network access
- ✅ No file system access beyond user-specified files
- ✅ Memory-safe Swift language

### Level 2: Signed Binary (With Developer ID)
- ✅ All Level 1 features
- ✅ Code signature verification
- ✅ Hardened Runtime protections
- ✅ Timestamp for signature validity
- ✅ Entitlements declaring limited capabilities

### Level 3: Notarized (With Developer ID + Notarization)
- ✅ All Level 2 features
- ✅ Apple malware scanning
- ✅ Gatekeeper approval
- ✅ Stapled ticket for offline verification
- ✅ User confidence in security

## Entitlements Explained

The `EnvPocket.entitlements` file declares:

- **No JIT compilation** - Prevents runtime code generation
- **No unsigned memory** - Blocks code injection
- **No dylib injection** - Prevents library hijacking
- **No network access** - Explicitly declares offline-only
- **No automation** - Cannot control other apps

## Keychain Access Groups (Optional)

For organizations, implement team-based isolation:

1. Add access group to keychain queries
2. Requires Team ID in code signature
3. Isolates envpocket's keychain items by team

## Distribution Recommendations

### For Personal Use
- Level 1 (Basic) is sufficient
- Build locally with `swift build -c release`

### For Team/Organization Use  
- Level 2 (Signed) recommended
- Provides signature verification
- Prevents tampering

### For Public Distribution
- Level 3 (Notarized) required
- Needed for Homebrew distribution
- Prevents Gatekeeper warnings

## Maintenance

When updating envpocket:

1. Increment version in Info.plist
2. Rebuild with security flags
3. Re-sign with entitlements
4. Re-notarize for distribution
5. Update Homebrew formula with new SHA256

## Security Best Practices

1. **Never commit signing credentials** to the repository
2. **Use app-specific passwords** for notarization
3. **Rotate credentials** periodically
4. **Verify signatures** before distribution
5. **Test on clean systems** to ensure Gatekeeper approval

## Resources

- [Apple Developer - Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [Apple Developer - Notarizing Command Line Tools](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)