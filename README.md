# EnvPocket

A secure command-line utility for macOS that stores environment files in the system keychain with automatic versioning and history management.

## Features

- **Secure Storage**: Uses macOS Keychain for encrypted storage of sensitive environment files
- **Version History**: Automatically maintains version history when files are updated
- **File Path Tracking**: Remembers original file locations for easy reference
- **Simple CLI**: Intuitive commands for saving, retrieving, and managing stored files
- **Atomic Operations**: Ensures data consistency during updates
- **Clean Namespace**: All keychain entries are prefixed to avoid conflicts

## Installation

### Using Homebrew (Recommended)

```bash
brew tap thieso2/envpocket
brew install envpocket
```

Or install directly without adding the tap:

```bash
brew install thieso2/envpocket/envpocket
```

### Using the Installation Script

```bash
curl -sSL https://github.com/thieso2/EnvPocket/releases/latest/download/install.sh | bash
```

### Building from Source

#### Prerequisites

- macOS 10.15 or later
- Swift 5.9 or later
- Xcode Command Line Tools

```bash
# Clone the repository
git clone https://github.com/thieso2/EnvPocket.git
cd EnvPocket

# Build the release version
swift build -c release

# Copy to a location in your PATH (optional)
sudo cp .build/release/envpocket /usr/local/bin/
```

### Quick Build

```bash
# Build and run directly
swift run envpocket <command> [args]
```

## Usage

### Save a File

Store a file in the keychain under a given key:

```bash
envpocket save myapp-prod .env.production
```

### Retrieve a File

Get the latest version of a stored file:

```bash
envpocket get myapp-prod .env
```

### Retrieve a Specific Version

Get a historical version by index (0 = most recent):

```bash
envpocket get myapp-prod --version 2 .env.backup
```

### List All Stored Files

View all stored keys with metadata:

```bash
envpocket list
```

Output shows:
- Original file paths
- Last modification dates
- Number of versions in history

### View Version History

See all available versions for a specific key:

```bash
envpocket history myapp-prod
```

### Delete a File

Remove a file and all its versions from the keychain:

```bash
envpocket delete myapp-prod
```

## Examples

### Managing Multiple Environment Files

```bash
# Store different environment configurations
envpocket save app-dev .env.development
envpocket save app-staging .env.staging
envpocket save app-prod .env.production

# List all stored configurations
envpocket list

# Retrieve specific environment
envpocket get app-staging .env
```

### Working with Versions

```bash
# Save initial version
envpocket save database-config db.conf

# Make changes and save again (previous version backed up automatically)
envpocket save database-config db.conf

# View history
envpocket history database-config

# Retrieve previous version
envpocket get database-config --version 1 db.conf.old
```

### Backup and Restore Workflow

```bash
# Backup all .env files
for file in .env*; do
  envpocket save "backup-$(basename $file)" "$file"
done

# Restore specific backup
envpocket get backup-.env.production .env.production
```

## Security Considerations

- **Keychain Access**: EnvPocket requires keychain access permissions on first use
- **User-Specific**: Stored items are only accessible by the current user
- **Encrypted Storage**: Data is encrypted by macOS Keychain Services
- **No Network Access**: All operations are local to your machine
- **Password Protection**: Keychain may require authentication based on your security settings

## Technical Details

### Storage Structure

- **Current Version**: Stored as `envpocket:<key>`
- **History Versions**: Stored as `envpocket-history:<key>:<timestamp>`
- **Timestamps**: ISO 8601 format for precise versioning
- **Metadata**: Original file paths and modification times preserved

### Keychain Item Type

Files are stored as generic password items (`kSecClassGenericPassword`) with:
- Account: Prefixed key name
- Data: File contents as binary
- Label: Original file path
- Comment: Last modification timestamp

## Troubleshooting

### Permission Denied

If you encounter keychain access issues:

1. Check System Preferences > Security & Privacy > Privacy > Full Disk Access
2. Ensure Terminal has necessary permissions
3. You may need to unlock your keychain: `security unlock-keychain`

### File Not Found

When retrieving files:
- Use `envpocket list` to verify the key exists
- Check spelling and case sensitivity
- Use `envpocket history <key>` to see available versions

### Build Errors

For Swift build issues:
- Verify Swift version: `swift --version`
- Update Xcode Command Line Tools: `xcode-select --install`
- Clean build artifacts: `swift package clean`

## Development

### Running Tests

```bash
swift test
```

### Debug Build

```bash
swift build
.build/debug/envpocket <command> [args]
```

### Project Structure

```
EnvPocket/
├── Package.swift           # Swift Package Manager manifest
├── Sources/
│   └── EnvPocket/
│       └── main.swift     # Main application source
└── Tests/
    └── EnvPocketTests/
        └── EnvPocketTests.swift
```

## Related Projects

- **Homebrew Tap**: [homebrew-envpocket](https://github.com/thieso2/homebrew-envpocket) - Official Homebrew formula for easy installation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with Swift and macOS Security Framework
- Inspired by the need for secure local environment file management
- Thanks to the Swift community for excellent documentation and tools