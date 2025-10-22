#!/bin/bash

################################################################################
# EasyPanel Build Script
# Creates .deb package and prepares for distribution
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_VERSION="1.0.0"
PACKAGE_NAME="easypanel"
OUTPUT_DIR="$SCRIPT_DIR/dist"

echo "======================================"
echo "EasyPanel Package Builder v$PROJECT_VERSION"
echo "======================================"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
chmod 755 "$OUTPUT_DIR"

# Copy scripts to debian package structure
echo "Preparing package files..."

# Create necessary directories
mkdir -p "$SCRIPT_DIR/debian/usr/local/bin"
mkdir -p "$SCRIPT_DIR/debian/usr/local/lib/easypanel/modules"

# Copy main script
cp "$SCRIPT_DIR/src/main.sh" "$SCRIPT_DIR/debian/usr/local/bin/easypanel-bin"
chmod 755 "$SCRIPT_DIR/debian/usr/local/bin/easypanel-bin"

# Copy wrapper script
if [ -f "$SCRIPT_DIR/debian/usr/local/bin/easypanel" ]; then
    chmod 755 "$SCRIPT_DIR/debian/usr/local/bin/easypanel"
else
    echo "Warning: easypanel wrapper not found at $SCRIPT_DIR/debian/usr/local/bin/easypanel"
fi

# Copy library script
cp "$SCRIPT_DIR/lib/utils.sh" "$SCRIPT_DIR/debian/usr/local/lib/easypanel/"
chmod 755 "$SCRIPT_DIR/debian/usr/local/lib/easypanel/"*.sh

# Copy module scripts
for script in "$SCRIPT_DIR/src"/*.sh; do
    if [ "$(basename "$script")" != "main.sh" ]; then
        cp "$script" "$SCRIPT_DIR/debian/usr/local/lib/easypanel/modules/"
        chmod 755 "$SCRIPT_DIR/debian/usr/local/lib/easypanel/modules/$(basename "$script")"
    fi
done

# Make postinst and postrm executable
chmod 755 "$SCRIPT_DIR/debian/DEBIAN/preinst"
chmod 755 "$SCRIPT_DIR/debian/DEBIAN/postinst"
chmod 755 "$SCRIPT_DIR/debian/DEBIAN/postrm"

# Ensure proper permissions on debian directories
find "$SCRIPT_DIR/debian" -type d -exec chmod 755 {} \;
find "$SCRIPT_DIR/debian" -type f ! -path '*/DEBIAN/*' -exec chmod 644 {} \;
find "$SCRIPT_DIR/debian/DEBIAN" -type f -exec chmod 755 {} \;

# Create md5sums file
echo "Creating md5sums..."
cd "$SCRIPT_DIR/debian"

find . -type f ! -path './DEBIAN/*' -exec md5sum {} \; > DEBIAN/md5sums

# Build .deb package
echo "Building .deb package..."

PACKAGE_FILE="$OUTPUT_DIR/${PACKAGE_NAME}_${PROJECT_VERSION}_all.deb"

dpkg-deb --build "$SCRIPT_DIR/debian" "$PACKAGE_FILE" 2>/dev/null

if [ -f "$PACKAGE_FILE" ]; then
    # Set proper permissions on the .deb file so apt can access it
    chmod 644 "$PACKAGE_FILE"
    # Make dist directory readable by all users
    chmod 755 "$OUTPUT_DIR"
    
    echo ""
    echo "✓ Package built successfully!"
    echo "  Output: $PACKAGE_FILE"
    echo "  Size: $(du -h "$PACKAGE_FILE" | cut -f1)"
    echo ""
    
    # Show package info
    echo "Package Information:"
    dpkg-deb -I "$PACKAGE_FILE"
    echo ""
    
    # Create SHA256 checksum
    sha256sum "$PACKAGE_FILE" > "$PACKAGE_FILE.sha256"
    echo "Checksum: $(cat "$PACKAGE_FILE.sha256")"
    echo ""
    
    # Installation instructions
    echo "======================================"
    echo "Installation Instructions:"
    echo "======================================"
    echo ""
    echo "To install:"
    echo "  sudo dpkg -i $PACKAGE_FILE"
    echo "  or"
    echo "  sudo apt install -y $PACKAGE_FILE"
    echo ""
    echo "To run:"
    echo "  sudo easypanel"
    echo ""
else
    echo "✗ Failed to build package"
    exit 1
fi

exit 0
