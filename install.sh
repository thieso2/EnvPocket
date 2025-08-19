#!/bin/bash

# EnvPocket Installation Script

set -e

echo "Installing EnvPocket..."

# Build in release mode
echo "Building release version..."
swift build -c release

# Default installation directory
INSTALL_DIR="/usr/local/bin"

# Check if we need sudo
if [ -w "$INSTALL_DIR" ]; then
    echo "Installing to $INSTALL_DIR..."
    cp .build/release/envpocket "$INSTALL_DIR/"
else
    echo "Installing to $INSTALL_DIR (requires sudo)..."
    sudo cp .build/release/envpocket "$INSTALL_DIR/"
fi

# Verify installation
if command -v envpocket &> /dev/null; then
    echo "✅ EnvPocket installed successfully!"
    echo "Run 'envpocket' to see usage information."
else
    echo "⚠️  Installation completed but 'envpocket' command not found in PATH."
    echo "You may need to add $INSTALL_DIR to your PATH or restart your terminal."
fi