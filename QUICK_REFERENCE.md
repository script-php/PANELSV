# Quick Reference: Certificate Storage Changes

## What Changed?

SSL certificates are now stored in each domain's directory instead of system paths.

### Old Way ❌
```
/etc/letsencrypt/live/domain.com/cert.pem
/etc/letsencrypt/live/domain.com/privkey.pem
```

### New Way ✅
```
/root/websites/domain.com/certificates/cert.pem
/root/websites/domain.com/certificates/privkey.pem
```

## Files Updated

| File | What Changed | Key Functions |
|------|-------------|-----------------|
| **lib/utils.sh** | Added cert copy function | `copy_ssl_certificates_local()` |
| **src/domains.sh** | Updated SSL paths & functions | `install_ssl_certificate()`, `renew_ssl_certificate()` |
| **src/cron.sh** | Added renewal script creation | `create_ssl_renewal_script()` |
| **docs/README.md** | Updated directory structure | Directory listing updated |
| **PROJECT_SUMMARY.md** | Updated feature description | Domain management section |

## How It Works Now

### 1. When You Add a Domain
```bash
easypanel domains add example.com

# Creates:
# /root/websites/example.com/
# ├── htdocs/
# ├── config/
# ├── logs/
# └── certificates/        ← NEW!
```

### 2. When SSL Certificate Is Installed
```bash
easypanel domains add example.com --ssl

# Process:
# 1. Certbot installs cert to /etc/letsencrypt/live/
# 2. copy_ssl_certificates_local() copies to:
#    /root/websites/example.com/certificates/
# 3. Web server configured to use new path
# 4. Service restarted
```

### 3. When Certificate Renews (Daily 03:00 AM)
```bash
# Cron job runs: /root/easypanel_ssl_renew.sh

# Process:
# 1. certbot renew updates Let's Encrypt certs
# 2. Script copies to all domain directories
# 3. Apache2 and Nginx reload automatically
# 4. No downtime
```

## Benefits Summary

| Benefit | Why It Matters |
|---------|----------------|
| **Single backup** | Backup entire domain with: `cp -r /root/websites/domain.com /backup/` |
| **Easy restore** | Restore entire domain: `cp -r /backup/domain.com /root/websites/` |
| **Better organized** | Certificates live with their domain |
| **Portable** | Move domain to new server without system config |
| **Secure** | Control per-domain file permissions |
| **Automatic** | Renewal maintains local copies automatically |

## Common Tasks

### View Certificates for a Domain
```bash
ls -la /root/websites/example.com/certificates/
```

### Manually Copy Certificates (If Needed)
```bash
cert_source="/etc/letsencrypt/live/example.com"
cert_dest="/root/websites/example.com/certificates"

cp -r "$cert_source"/* "$cert_dest/"
chmod 644 "$cert_dest"/*.pem
chmod 600 "$cert_dest"/privkey.pem
chown -R root:root "$cert_dest"
```

### Backup Domain with Certificates
```bash
# All in one: code, config, logs, AND certificates
tar -czf domain_backup.tar.gz /root/websites/example.com/
```

### Verify Web Server Uses New Paths
```bash
# Apache2
grep -r "certificates" /etc/apache2/sites-available/

# Nginx
grep -r "certificates" /etc/nginx/sites-available/
```

## Troubleshooting

### Problem: Web server won't start after SSL
**Solution:** Check certificate paths in config:
```bash
# Apache2
nano /etc/apache2/sites-available/domain.com.conf
# Look for: /root/websites/domain.com/certificates/

# Nginx
nano /etc/nginx/sites-available/domain.com
# Look for: /root/websites/domain.com/certificates/
```

### Problem: Certificate files missing after renewal
**Solution:** Check cron job status:
```bash
# Verify cron exists
crontab -l | grep easypanel_ssl_renew

# Run renewal manually
/root/easypanel_ssl_renew.sh

# Check cron logs
grep easypanel_ssl_renew /var/log/syslog
```

### Problem: Permission denied on certificate
**Solution:** Fix permissions:
```bash
domain="example.com"
chmod 644 /root/websites/$domain/certificates/*.pem
chmod 600 /root/websites/$domain/certificates/privkey.pem
chown -R root:root /root/websites/$domain/certificates/
```

## Verification Checklist

Use this to verify everything is working:

```bash
#!/bin/bash
domain="example.com"

echo "✓ Checking certificate storage..."

# 1. Directory exists
[ -d "/root/websites/$domain/certificates/" ] && echo "✓ Directory exists" || echo "✗ Directory missing"

# 2. Certificates present
[ -f "/root/websites/$domain/certificates/privkey.pem" ] && echo "✓ Private key exists" || echo "✗ Private key missing"
[ -f "/root/websites/$domain/certificates/cert.pem" ] && echo "✓ Certificate exists" || echo "✗ Certificate missing"

# 3. Permissions correct
perms=$(stat -c "%a" /root/websites/$domain/certificates/privkey.pem)
[ "$perms" = "600" ] && echo "✓ Private key permissions correct" || echo "✗ Permissions wrong: $perms"

# 4. Web server configured
grep -q "/root/websites/$domain/certificates/" /etc/apache2/sites-available/$domain.conf 2>/dev/null && echo "✓ Apache2 configured" || echo "? Apache2 check"
grep -q "/root/websites/$domain/certificates/" /etc/nginx/sites-available/$domain 2>/dev/null && echo "✓ Nginx configured" || echo "? Nginx check"

# 5. Cron job exists
crontab -l | grep -q "easypanel_ssl_renew" && echo "✓ Cron job configured" || echo "✗ Cron job missing"

echo "✓ Verification complete"
```

## Documentation

- Full details: **CERTIFICATE_STORAGE_UPDATE.md**
- Implementation summary: **IMPLEMENTATION_SUMMARY.md**
- General docs: **docs/README.md**
- Project overview: **PROJECT_SUMMARY.md**

---

**Questions?** Check the detailed documentation files for more information.
