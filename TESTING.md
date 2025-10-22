# EasyPanel - Testing & Deployment Guide

## Pre-Installation Testing

### System Compatibility Check

```bash
# Check OS version
lsb_release -a

# Check if running as root
whoami

# Check disk space
df -h /

# Check RAM
free -h

# Check internet connectivity
ping -c 1 8.8.8.8
```

### Required Commands Check

```bash
# Essential commands
which bash
which curl
which wget
which systemctl
which tar
```

## Installation Testing

### 1. Development Installation (Direct Scripts)

```bash
# Test from source
cd /path/to/PANELSV

# Make scripts executable
chmod +x src/*.sh lib/*.sh build.sh

# Test main script
sudo bash src/main.sh help

# Test installation wizard (dry-run)
sudo bash src/install.sh
```

### 2. Module Testing

Test each module independently:

```bash
# Source utilities
source lib/utils.sh

# Test domains module
source src/domains.sh
print_header "Testing Domains"

# Test DNS module
source src/dns.sh
print_header "Testing DNS"

# Test mail module
source src/mail.sh
print_header "Testing Mail"

# Test database module
source src/databases.sh
print_header "Testing Databases"

# Test cron module
source src/cron.sh
print_header "Testing Cron"

# Test backup module
source src/backup.sh
print_header "Testing Backup"

# Test settings module
source src/settings.sh
print_header "Testing Settings"
```

### 3. Package Building Test

```bash
# Build the package
sudo bash build.sh

# Verify package
sudo dpkg -I dist/easypanel_1.0.0_all.deb

# Check package contents
sudo dpkg-deb -c dist/easypanel_1.0.0_all.deb

# Verify checksums
sha256sum -c dist/easypanel_1.0.0_all.deb.sha256
```

### 4. Package Installation Test

```bash
# Install package
sudo dpkg -i dist/easypanel_1.0.0_all.deb

# Verify installation
which easypanel
ls -la /usr/local/bin/easypanel*
ls -la /etc/easypanel/

# Test basic functionality
sudo easypanel help
sudo easypanel version
```

## Functional Testing

### Web Server Installation Test

```bash
# Run installation
sudo easypanel install

# Test menu selections:
# 1. Apache2 or Nginx
# 2. MySQL or MariaDB
# 3. PHP versions
# 4. DNS setup
# 5. Mail setup
# 6. Firewall setup

# Verify services
sudo systemctl status nginx
sudo systemctl status apache2
sudo systemctl status mysql
sudo systemctl status mariadb
```

### Domain Management Test

```bash
# Test adding domain
sudo easypanel domains

# Follow prompts to add:
# - domain: test.local
# - DNS support: yes
# - Mail support: yes
# - SSL: yes (if connectivity allows)

# Verify structure
ls -la /root/websites/test.local/

# Expected structure:
# - htdocs/ directory
# - config/ directory
# - logs/ directory
```

### Web Server Configuration Test

```bash
# For Nginx
sudo nginx -t
sudo systemctl restart nginx

# For Apache2
sudo apache2ctl -t
sudo systemctl restart apache2

# Check website
curl http://test.local
```

### Database Test

```bash
# Test adding database
sudo easypanel databases

# Create database: testdb
# Create user: testuser

# Verify in MySQL/MariaDB
sudo mysql -u root -proot

mysql> SHOW DATABASES;
mysql> SHOW USERS;
mysql> exit;
```

### DNS Test

```bash
# Test DNS functionality
sudo easypanel dns

# Create zone for test.local
# Add A record pointing to 127.0.0.1

# Verify DNS
sudo nslookup test.local localhost
```

### Mail Test

```bash
# Test mail functionality
sudo easypanel mail

# Add account: test@test.local
# Configure DKIM: yes

# Verify mail user
ls -la /home/mail/

# Test Dovecot/Postfix
sudo systemctl status postfix
sudo systemctl status dovecot
```

### Cron Test

```bash
# Test cron functionality
sudo easypanel cron

# Add website backup cron
# Add database backup cron

# Verify cron
sudo crontab -l -u root

# Should show backup jobs
```

### Backup Test

```bash
# Test backup functionality
sudo easypanel backup

# Create website backup
# Create database backup

# Verify backups
ls -la /root/backups/

# Test restoration (optional)
```

## Integration Testing

### Full Workflow Test

1. **Install EasyPanel**
   ```bash
   sudo dpkg -i dist/easypanel_1.0.0_all.deb
   sudo easypanel install
   ```

2. **Add Domain**
   ```bash
   sudo easypanel domains
   # Add: example.com
   ```

3. **Create Database**
   ```bash
   sudo easypanel databases
   # Create: example_db
   ```

4. **Add Mail Account**
   ```bash
   sudo easypanel mail
   # Add: admin@example.com
   ```

5. **Configure DNS**
   ```bash
   sudo easypanel dns
   # Create zone and records
   ```

6. **Create Backup**
   ```bash
   sudo easypanel backup
   # Backup website and database
   ```

7. **Verify Everything**
   ```bash
   sudo easypanel status
   ```

## Performance Testing

### Stress Testing

```bash
# Create multiple domains
for i in {1..10}; do
    sudo easypanel domains
    # Add domain$i.test
done

# Create multiple databases
for i in {1..5}; do
    sudo easypanel databases
    # Create db$i
done

# Monitor system
htop
```

### Backup Performance

```bash
# Measure backup time
time sudo easypanel backup
# Full system backup

# Check backup sizes
du -sh /root/backups/*
```

## Security Testing

### Firewall Test

```bash
# Test firewall rules
sudo ufw status

# Check fail2ban
sudo fail2ban-client status

# Verify iptables
sudo iptables -L -n
```

### SSL Certificate Test

```bash
# Check certificate
sudo openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout

# Test HTTPS
curl -I https://example.com
```

### Database Security Test

```bash
# Try connecting with root
mysql -u root -proot

# Verify users
SELECT user, host FROM mysql.user;

# Check privileges
SHOW GRANTS FOR 'testuser'@'localhost';
```

## Error Handling Test

### Test Error Scenarios

1. **Invalid Domain Name**
   ```bash
   sudo easypanel domains
   # Try adding: invalid_domain
   # Should show error
   ```

2. **Duplicate Database**
   ```bash
   sudo easypanel databases
   # Try creating duplicate
   # Should show error
   ```

3. **Invalid Cron Schedule**
   ```bash
   sudo easypanel cron
   # Try invalid schedule
   # Should show error
   ```

4. **Missing Required Input**
   ```bash
   # Try skipping required fields
   # Should show error
   ```

### Check Error Logs

```bash
# View EasyPanel logs
sudo tail -f /var/log/easypanel.log

# View web server logs
sudo tail -f /var/log/nginx/error.log
# or
sudo tail -f /var/log/apache2/error.log

# View system logs
sudo tail -f /var/log/syslog
```

## Deployment Checklist

- [ ] All modules tested individually
- [ ] Installation wizard works
- [ ] Web server configuration verified
- [ ] Database operations working
- [ ] Mail setup functional
- [ ] DNS management working
- [ ] Cron jobs configurable
- [ ] Backups created successfully
- [ ] Restoration tested
- [ ] Security features enabled
- [ ] Error handling verified
- [ ] Documentation accurate
- [ ] Package builds successfully
- [ ] Package installs correctly
- [ ] Performance acceptable

## Production Deployment Steps

1. **Prepare Server**
   ```bash
   sudo apt update
   sudo apt upgrade
   sudo reboot
   ```

2. **Install EasyPanel**
   ```bash
   sudo dpkg -i easypanel_1.0.0_all.deb
   ```

3. **Run Installation Wizard**
   ```bash
   sudo easypanel install
   ```

4. **Secure System**
   ```bash
   sudo easypanel
   # Settings → Change Database Password
   # Settings → Firewall Configuration
   ```

5. **Add Domains**
   ```bash
   sudo easypanel domains
   # Add all your domains
   ```

6. **Configure Backups**
   ```bash
   sudo easypanel cron
   # Add backup jobs
   ```

7. **Set Up Monitoring**
   ```bash
   # Check status regularly
   sudo easypanel status
   ```

## Troubleshooting Test Matrix

| Issue | Test | Expected Result |
|-------|------|-----------------|
| Script not executable | `chmod +x *.sh` | Scripts run |
| Module not found | `source src/module.sh` | Module loads |
| Configuration not found | `cat /etc/easypanel/config` | Config exists |
| Service not running | `systemctl status service` | Service shows status |
| Permission denied | `sudo easypanel` | Runs with sudo |
| Invalid input | Test with bad data | Shows error message |

## Quick Test Commands

```bash
# Quick full test
sudo bash test.sh 2>&1 | tee test_results.log

# Test syntax of all scripts
for file in src/*.sh lib/*.sh; do
    bash -n "$file" && echo "✓ $file" || echo "✗ $file"
done

# Count lines of code
wc -l src/*.sh lib/*.sh

# Find potential issues
shellcheck src/*.sh lib/*.sh

# Test menu navigation
sudo easypanel help
sudo easypanel version
sudo easypanel status
```

## Before Going Live

- [ ] Test all features thoroughly
- [ ] Verify documentation accuracy
- [ ] Check error messages clarity
- [ ] Ensure log files working
- [ ] Test backup/restore
- [ ] Verify SSL certificates
- [ ] Test mail functionality
- [ ] Check DNS records
- [ ] Verify cron jobs
- [ ] Test database operations
- [ ] Security audit completed
- [ ] Performance acceptable
- [ ] Documentation complete
- [ ] Support resources ready

---

**Testing Version:** 1.0.0
**Test Date:** Ready for testing
**Status:** Deployment ready
