# Certificate Storage Update - Local Per-Domain Storage

## Overview

SSL certificates are now stored locally within each domain's directory structure instead of in system-wide paths. This provides better organization, easier backups, and simplified domain portability.

## Changes Made

### 1. **Directory Structure Enhancement** (`lib/utils.sh`)
- Updated `create_domain_structure()` function to create `/certificates/` directory
- New path: `/root/websites/domain.com/certificates/`
- Automatically created when a domain is added

### 2. **Certificate Storage Function** (`lib/utils.sh`)
- Added new utility function: `copy_ssl_certificates_local()`
- Copies certificates from Let's Encrypt to local domain storage
- Sets proper permissions:
  - Public certificates: `644` (readable)
  - Private key: `600` (read-only by root)
  - Owner: `root:root`

### 3. **Web Server Configuration Updates** (`src/domains.sh`)

#### Apache2 Virtual Host
**Before:**
```apache
SSLCertificateFile /etc/letsencrypt/live/$domain/cert.pem
SSLCertificateKeyFile /etc/letsencrypt/live/$domain/privkey.pem
SSLCertificateChainFile /etc/letsencrypt/live/$domain/chain.pem
```

**After:**
```apache
SSLCertificateFile /root/websites/$domain/certificates/cert.pem
SSLCertificateKeyFile /root/websites/$domain/certificates/privkey.pem
SSLCertificateChainFile /root/websites/$domain/certificates/chain.pem
```

#### Nginx Server Block
**Before:**
```nginx
ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
```

**After:**
```nginx
ssl_certificate /root/websites/$domain/certificates/fullchain.pem;
ssl_certificate_key /root/websites/$domain/certificates/privkey.pem;
```

### 4. **SSL Installation Process** (`src/domains.sh`)
- Updated `install_ssl_certificate()` function
- After certbot installation, automatically copies certificates to local storage
- Calls `copy_ssl_certificates_local()` helper function
- Maintains web server compatibility

### 5. **Certificate Renewal Process** (`src/domains.sh`)
- Updated `renew_ssl_certificate()` function
- After certbot renewal, updates local copies
- Keeps certificates in sync automatically

### 6. **Cron Job Automation** (`src/cron.sh`)
- Created `create_ssl_renewal_script()` function
- New script: `/root/easypanel_ssl_renew.sh`
- Runs at 03:00 AM daily (configurable)
- Automatically:
  - Runs certbot renew
  - Copies renewed certificates to all domain directories
  - Reloads web servers (Apache2 and Nginx)

### 7. **Documentation Updates**
- Updated `docs/README.md` with new directory structure
- Updated `PROJECT_SUMMARY.md` to highlight local certificate storage
- Added documentation of the certificates/ directory

## Benefits

### 1. **Backup & Restore**
- All domain data (code, config, logs, certificates) in one location
- Single backup of `/root/websites/domain.com/` includes everything
- Easier restoration on new servers

### 2. **Organization**
- Certificates organized by domain
- Clear relationship between certificates and their domains
- Simplified certificate management

### 3. **Portability**
- Move domain to different server: copy one directory
- All necessary files included
- No system-wide dependencies

### 4. **Security**
- Certificates with domain data
- Easier to audit and control access
- Per-domain certificate permissions

### 5. **Maintenance**
- Automated renewal maintains local copies
- Web server reload included in cron job
- No manual intervention required

## Implementation Details

### Certificate Copy Process
```bash
copy_ssl_certificates_local() {
    local domain="$1"
    local cert_source="/etc/letsencrypt/live/$domain"
    local cert_dest="$WEBSITES_ROOT/$domain/certificates"
    
    # Copy all certificate files
    cp -r "$cert_source"/* "$cert_dest/" 2>/dev/null
    
    # Set proper permissions
    chmod 644 "$cert_dest"/*.pem 2>/dev/null      # Public certs readable
    chmod 600 "$cert_dest"/privkey.pem 2>/dev/null # Private key secured
    chown -R root:root "$cert_dest" 2>/dev/null   # Owned by root
}
```

### Automated Renewal Cron Job
```bash
# /root/easypanel_ssl_renew.sh
#!/bin/bash

# Renew all certificates
certbot renew --non-interactive --quiet 2>/dev/null

# Copy renewed certificates to domain directories
WEBSITES_ROOT="/root/websites"
for domain_dir in "$WEBSITES_ROOT"/*; do
    domain=$(basename "$domain_dir")
    cert_source="/etc/letsencrypt/live/$domain"
    cert_dest="$domain_dir/certificates"
    
    if [ -d "$cert_source" ] && [ -d "$cert_dest" ]; then
        cp -r "$cert_source"/* "$cert_dest/" 2>/dev/null
        chmod 644 "$cert_dest"/*.pem 2>/dev/null
        chmod 600 "$cert_dest"/privkey.pem 2>/dev/null
        chown -R root:root "$cert_dest" 2>/dev/null
    fi
done

# Reload web servers
systemctl reload apache2 2>/dev/null
systemctl reload nginx 2>/dev/null
```

## File Structure After Certificate Installation

```
/root/websites/domain.com/
├── htdocs/                      # Website files
├── config/                      # Web server configs
├── logs/                        # Access/error logs
└── certificates/                # SSL certificates
    ├── cert.pem                # Certificate
    ├── chain.pem               # Chain
    ├── fullchain.pem           # Full chain (Nginx)
    └── privkey.pem             # Private key
```

## Migration from System Storage

Existing installations with certificates in `/etc/letsencrypt/`:
1. Certificates can remain in system storage (backward compatible)
2. New installations automatically use local storage
3. Manual migration: Copy certs from `/etc/letsencrypt/live/domain/` to `/root/websites/domain/certificates/`

## Related Files Modified

1. **lib/utils.sh** - Added `copy_ssl_certificates_local()` function
2. **src/domains.sh** - Updated SSL certificate paths and functions
3. **src/cron.sh** - Added `create_ssl_renewal_script()` and updated SSL renewal cron
4. **docs/README.md** - Updated directory structure documentation
5. **PROJECT_SUMMARY.md** - Highlighted local certificate storage feature

## Testing Checklist

- [x] Domain creation creates certificates/ directory
- [x] SSL certificate installation copies certs to local storage
- [x] Apache2 loads certificates from new path
- [x] Nginx loads certificates from new path
- [x] Certificate renewal updates local copies
- [x] Cron job runs and updates all domain certificates
- [x] Web server reloads after certificate renewal

## Future Enhancements

- Certificate monitoring and expiration alerts
- Automated certificate backup
- Certificate validity checking
- Wildcard certificate support improvements
- Multi-domain SAN certificate support
