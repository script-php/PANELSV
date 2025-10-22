# EasyPanel Build & Installation Troubleshooting Guide

## Build Issues

### Issue 1: "cp cannot create regular file... no such file or directory"

**Error Message:**
```
cp cannot create regular file '/home/dev/PANELSV/debian/usr/local/bin/easypanel-bin' 
no such file or directory
```

**Cause:** Directories don't exist in the debian package structure

**Solution:**
- ✅ Already fixed in build.sh
- Directories are created with `mkdir -p` before copying
- Update your build.sh to latest version

**Manual Fix (if needed):**
```bash
mkdir -p debian/usr/local/bin
mkdir -p debian/usr/local/lib/easypanel/modules
bash build.sh
```

---

### Issue 2: "download is performed unsandboxed as root as file... permission denied"

**Error Message:**
```
download is performed unsandboxed as root as file 'home/dev/PANELSV/dist/easypanel_1.0.0_all.deb' 
could not be accessed by user '_apt'. - pkgAcquire::Run (13: permission denied)
```

**Cause:** The .deb file or containing directory has restricted permissions

**Solution:**
- ✅ Already fixed in build.sh
- Permissions are now set properly: `chmod 644` on .deb, `chmod 755` on directories
- Update your build.sh to latest version

**Manual Fix (if needed):**
```bash
chmod 755 dist/
chmod 644 dist/easypanel_1.0.0_all.deb
```

Then retry installation:
```bash
sudo apt install -y ./dist/easypanel_1.0.0_all.deb
```

---

### Issue 3: Build command not found

**Error Message:**
```
bash: build.sh: command not found
```

**Cause:** Not running with bash explicitly or wrong directory

**Solution:**
```bash
cd /path/to/PANELSV
bash build.sh          # Correct
# or
./build.sh             # If marked executable: chmod +x build.sh
# NOT:
build.sh               # Wrong - won't work
```

---

## Installation Issues

### Issue 4: "dpkg: error processing package"

**Cause:** Missing dependencies or corrupted package

**Solution:**

Step 1: Rebuild the package
```bash
cd /path/to/PANELSV
bash build.sh
```

Step 2: Try installation with dependencies
```bash
sudo apt install -y ./dist/easypanel_1.0.0_all.deb
```

Step 3: If still fails, install dependencies manually
```bash
sudo apt install -y bash sed grep coreutils
```

---

### Issue 5: "easypanel: command not found" after installation

**Cause:** Command not in PATH or not installed properly

**Solution:**

Step 1: Check if installed
```bash
dpkg -l | grep easypanel
```

Step 2: Check installation files
```bash
ls -la /usr/local/bin/easypanel*
ls -la /usr/local/lib/easypanel/
```

Step 3: Reinstall if needed
```bash
sudo dpkg -i dist/easypanel_1.0.0_all.deb
```

Step 4: Verify PATH
```bash
echo $PATH
# Should include /usr/local/bin
```

---

### Issue 6: Permission denied when running easypanel

**Cause:** Script doesn't have execute permissions

**Solution:**
```bash
sudo chmod 755 /usr/local/bin/easypanel-bin
sudo chmod 755 /usr/local/lib/easypanel/utils.sh
sudo chmod 755 /usr/local/lib/easypanel/modules/*.sh
```

---

## Pre-Build Checklist

Before running build.sh, verify:

```bash
# Check build.sh exists
[ -f build.sh ] && echo "✓ build.sh exists" || echo "✗ build.sh missing"

# Check src/ scripts exist
[ -d src ] && echo "✓ src/ directory exists" || echo "✗ src/ missing"
[ -f src/main.sh ] && echo "✓ main.sh exists" || echo "✗ main.sh missing"
[ -f lib/utils.sh ] && echo "✓ utils.sh exists" || echo "✗ utils.sh missing"

# Check debian structure
[ -d debian ] && echo "✓ debian/ exists" || echo "✗ debian/ missing"
[ -d debian/DEBIAN ] && echo "✓ DEBIAN/ exists" || echo "✗ DEBIAN/ missing"

# Check you have build tools
command -v dpkg-deb &>/dev/null && echo "✓ dpkg-deb found" || echo "✗ dpkg-deb missing"
```

---

## Post-Build Verification

After successful build:

```bash
# Check .deb file exists and has right permissions
ls -lh dist/easypanel_1.0.0_all.deb
# Should show: -rw-r--r-- (644 permissions)

# Verify .deb package integrity
dpkg-deb -I dist/easypanel_1.0.0_all.deb | head -5

# Check SHA256 checksum exists
[ -f dist/easypanel_1.0.0_all.deb.sha256 ] && echo "✓ Checksum generated"
```

---

## Installation Step-by-Step

### Safe Installation Process

```bash
# 1. Navigate to project directory
cd /path/to/PANELSV

# 2. Build the package
bash build.sh

# 3. Check build succeeded
[ -f dist/easypanel_1.0.0_all.deb ] && echo "✓ Build successful" || echo "✗ Build failed"

# 4. Check permissions
ls -l dist/easypanel_1.0.0_all.deb
# Should be: -rw-r--r--

# 5. Install with apt (recommended)
sudo apt install -y ./dist/easypanel_1.0.0_all.deb

# 6. Or install with dpkg (if apt fails)
sudo dpkg -i dist/easypanel_1.0.0_all.deb

# 7. Verify installation
which easypanel

# 8. Run the application
sudo easypanel
```

---

## Common Build Errors & Quick Fixes

| Error | Quick Fix |
|-------|-----------|
| `No such file or directory` (during cp) | Run latest build.sh with mkdir fix |
| `Permission denied` (_apt error) | Run latest build.sh with chmod fix |
| `dpkg-deb: command not found` | `sudo apt install -y dpkg` |
| `set: command not found` | Use `bash build.sh` not `./build.sh` |
| `Bad permissions` on resulting .deb | Update build.sh line 65: `chmod 644 "$PACKAGE_FILE"` |

---

## Cleaning Up Failed Builds

If you need to rebuild after a failed attempt:

```bash
# Option 1: Clean dist directory
rm -rf dist/
bash build.sh

# Option 2: Reset debian directory
find debian -type f ! -path 'debian/DEBIAN/*' -delete
bash build.sh

# Option 3: Clean everything
rm -rf dist/
find debian -type f ! -path 'debian/DEBIAN/*' -delete
bash build.sh
```

---

## Uninstalling

If installation fails and you need to remove:

```bash
# Uninstall the package
sudo dpkg -r easypanel

# Or force remove if needed
sudo dpkg --remove --force-all easypanel

# Clean up config (optional)
sudo rm -rf /etc/easypanel
```

---

## Getting Help

If you still have issues:

1. **Check build.sh version:**
   ```bash
   grep "PROJECT_VERSION" build.sh
   ```

2. **Enable debug output:**
   ```bash
   bash -x build.sh 2>&1 | head -50
   ```

3. **Check system logs:**
   ```bash
   sudo tail -20 /var/log/apt/term.log
   sudo journalctl -xe
   ```

4. **Verify permissions:**
   ```bash
   stat dist/easypanel_1.0.0_all.deb
   ```

---

## Version Information

This troubleshooting guide is for:
- **EasyPanel Version:** 1.0.0
- **Build Script:** Latest (with mkdir and chmod fixes)
- **Supported OS:** Debian/Ubuntu

---

**Last Updated:** Current Session
**Status:** Comprehensive troubleshooting guide
