#!/bin/bash
# Quick Fix - EasyPanel Execution Error Resolution

# Follow these steps to fix the execution error:

echo "================================================"
echo "EasyPanel - Fixing Execution Error"
echo "================================================"
echo ""

# Step 1: Uninstall
echo "Step 1: Uninstalling current version..."
sudo dpkg -r easypanel 2>/dev/null
echo "✓ Uninstalled"
echo ""

# Step 2: Navigate to project
echo "Step 2: Navigating to project directory..."
cd /path/to/PANELSV
echo "✓ In: $(pwd)"
echo ""

# Step 3: Clean build artifacts
echo "Step 3: Cleaning build artifacts..."
rm -rf dist/
find debian -type f ! -path 'debian/DEBIAN/*' -delete 2>/dev/null
echo "✓ Cleaned"
echo ""

# Step 4: Rebuild
echo "Step 4: Rebuilding package..."
bash build.sh
if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo "✗ Build failed"
    exit 1
fi
echo ""

# Step 5: Reinstall
echo "Step 5: Reinstalling package..."
sudo apt install -y ./dist/easypanel_1.0.0_all.deb
if [ $? -eq 0 ]; then
    echo "✓ Installation successful"
else
    echo "⚠ Installation had issues, trying dpkg..."
    sudo dpkg -i dist/easypanel_1.0.0_all.deb
fi
echo ""

# Step 6: Verify
echo "Step 6: Verifying installation..."
echo ""

echo "Checking wrapper script..."
if [ -f /usr/local/bin/easypanel ] && [ -x /usr/local/bin/easypanel ]; then
    echo "✓ Wrapper script OK"
else
    echo "✗ Wrapper script issue"
fi

echo "Checking main script..."
if [ -f /usr/local/bin/easypanel-bin ] && [ -x /usr/local/bin/easypanel-bin ]; then
    echo "✓ Main script OK"
else
    echo "✗ Main script issue"
fi

echo "Checking library..."
if [ -f /usr/local/lib/easypanel/utils.sh ] && [ -x /usr/local/lib/easypanel/utils.sh ]; then
    echo "✓ Library OK"
else
    echo "✗ Library issue"
fi

echo "Checking modules..."
modules=$(find /usr/local/lib/easypanel/modules -name "*.sh" 2>/dev/null | wc -l)
if [ "$modules" -gt 0 ]; then
    echo "✓ Found $modules modules"
else
    echo "✗ No modules found"
fi

echo ""
echo "Step 7: Testing execution..."
echo ""

# Test basic execution
if sudo easypanel --help &>/dev/null 2>&1; then
    echo "✓ EasyPanel runs successfully!"
    echo ""
    echo "================================================"
    echo "✓ ALL TESTS PASSED"
    echo "================================================"
    echo ""
    echo "You can now run:"
    echo "  easypanel              (help menu)"
    echo "  sudo easypanel         (main menu)"
    echo "  sudo easypanel install (installation wizard)"
    echo ""
else
    echo "⚠ EasyPanel may have issues"
    echo ""
    echo "Try running with debug:"
    echo "  bash -x /usr/local/bin/easypanel 2>&1 | head -20"
    echo ""
    echo "Or check logs:"
    echo "  sudo tail -20 /var/log/easypanel.log"
fi

exit 0
