# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

envpocket is a macOS command-line utility that securely stores environment files in the system keychain. It provides versioning support and maintains a complete history of all stored files.

## Build and Development Commands

### Building
```bash
# Debug build
swift build

# Release build (optimized)
swift build -c release

# Build and copy to current directory
swift build -c release && cp .build/release/envpocket ./
```

### Running
```bash
# Via Swift Package Manager
swift run envpocket <command> [args]

# Via built executable
.build/release/envpocket <command> [args]
```

### Testing
```bash
swift test
```

## Architecture

Single-file Swift executable (`Sources/EnvPocket/main.swift`) that:

1. **Keychain Integration**: Uses macOS Security framework for secure storage
2. **Namespacing**: All entries prefixed with `envpocket:` (current) or `envpocket-history:` (versions)
3. **Version Management**: Automatic versioning on updates with ISO8601 timestamps
4. **Data Storage**: Files stored as binary data in `kSecClassGenericPassword` items
5. **Metadata Tracking**: Preserves original file paths and modification timestamps

## Key Implementation Details

- **Storage Format**: 
  - Current: `envpocket:<key>` 
  - History: `envpocket-history:<key>:<ISO8601-timestamp>`
- **File Path Preservation**: Original paths stored in `kSecAttrLabel`
- **Atomic Operations**: Delete-then-add pattern ensures consistency
- **History Cascade**: Deleting a key removes all associated versions
- **Error Handling**: Exits with status 1 on failure with descriptive messages
- compile withoput warnings