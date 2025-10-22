# EasyPanel - Terminal-Based Web Server Control Panel

A comprehensive, terminal-based control panel for managing web servers on Linux (Debian/Ubuntu). EasyPanel provides an intuitive interface for managing domains, databases, mail servers, DNS, backups, and more.

## Features

### 🌐 Web Server Management
- **Apache2** and **Nginx** support with easy switching
- Automatic virtual host configuration
- Custom domain-specific configuration support
- Automatic web server restart and configuration validation

### 📁 Domain Management
- Add/Edit/Delete domains with ease
- Automatic directory structure creation (`htdocs`, `logs`, `config`)
- SSL certificate management with Let's Encrypt integration
- Automatic renewal of SSL certificates
- Per-domain error and access logs
- Support for subdomains

### 🗄️ Database Management
- **MySQL** and **MariaDB** support
- Create/manage databases and users
- Database backup and restore
- Database optimization and repair
- User privilege management
- Character set and collation configuration

### 📧 Mail Server Management
- Full mail server setup (Postfix, Dovecot)
- Multiple mail account management
- DKIM key generation and management
- SMTP relay configuration
- Roundcube webmail integration
- Sieve mail filter support
- Anti-spam (SpamAssassin) and Anti-virus (ClamAV) integration

### 🔗 DNS Management
- DNS zone creation and management using BIND9
- Support for multiple record types:
  - A and AAAA records
  - CNAME, MX, NS, TXT records
- Zone file editing and validation
- Automatic serial number management
- Support for DNS clustering

### 🔐 Security Features
- Let's Encrypt SSL certificate support with wildcard certificates
- Firewall configuration (iptables, fail2ban, ipset)
- Brute-force attack detection
- IP whitelisting/blacklisting
- SSH security configuration

### ⏰ Automation
- Cron job management
- Pre-configured backup jobs
- SSL renewal automation
- Custom schedule creation
- System update scheduling

### 💾 Backup & Restore
- Website backups
- Database backups
- Full system backups
- Automatic backup scheduling
- Backup restoration
- Old backup cleanup

### 📊 Additional Features
- System monitoring and status
- Service management
- Log viewing
- Configuration management
- Multi-PHP version support (5.6 - 8.4)

## System Requirements

### Minimum
- Ubuntu 18.04 LTS / Debian 10 or newer
- 500MB free disk space
- 512MB RAM (1GB+ recommended)
- Root or sudo access

### Recommended
- Ubuntu 22.04 LTS / Debian 12+
- 2GB+ free disk space
- 2GB+ RAM
- Static IP address
- Registered domain name(s)

## Installation

### From .deb Package

```bash
# Download the latest package
wget https://github.com/easypanel/easypanel/releases/download/v1.0.0/easypanel_1.0.0_all.deb

# Install the package
sudo dpkg -i easypanel_1.0.0_all.deb

# Or using apt
sudo apt install -y ./easypanel_1.0.0_all.deb
```

### From Source

```bash
# Clone the repository
git clone https://github.com/easypanel/easypanel.git
cd easypanel

# Build the package
sudo bash build.sh

# Install
sudo dpkg -i dist/easypanel_*.deb
```

## Quick Start

### 1. Run Installation Wizard

```bash
sudo easypanel install
```

The wizard will guide you through:
- Selecting web server (Apache2 or Nginx)
- Selecting database (MySQL or MariaDB)
- Installing PHP-FPM
- Setting up mail server (optional)
- Installing DNS server (optional)
- Configuring firewall

### 2. Add Your First Domain

```bash
sudo easypanel domains
```

Select "Add Domain" and follow the prompts to:
- Enter domain name
- Enable DNS support
- Enable mail support
- Install SSL certificate

### 3. Create a Database

```bash
sudo easypanel databases
```

Create databases and manage users for your applications.

### 4. Configure Mail (Optional)

```bash
sudo easypanel mail
```

Set up mail accounts with DKIM and other features.

## Usage

### Main Menu

```bash
sudo easypanel
```

Interactive menu with options:
- 1) Install/Setup
- 2) Manage Domains
- 3) Manage DNS
- 4) Manage Mail
- 5) Manage Databases
- 6) Manage Cron Jobs
- 7) Backup & Restore
- 8) System Status
- 9) Settings
- 0) Exit

### Direct Commands

```bash
# Show interactive menu
sudo easypanel

# Run installation wizard
sudo easypanel install

# Go directly to domains
sudo easypanel domains

# Go directly to DNS management
sudo easypanel dns

# Go directly to mail management
sudo easypanel mail

# Go directly to database management
sudo easypanel databases

# Manage cron jobs
sudo easypanel cron

# Backup and restore
sudo easypanel backup

# Show system status
sudo easypanel status

# Show help
sudo easypanel help

# Show version
sudo easypanel version
```

## Directory Structure

```
/root/websites/
├── domain1.com/
│   ├── htdocs/          # Website files
│   ├── config/          # Custom web server configs
│   └── logs/            # Access and error logs
├── domain2.com/
│   ├── htdocs/
│   ├── config/
│   └── logs/
...

/etc/easypanel/
├── config               # Main configuration
├── mail/                # Mail configuration
└── cron/                # Cron job definitions

/root/backups/
├── websites/            # Website backups
├── databases/           # Database backups
└── full/                # Full system backups
```

## Configuration

### Main Configuration File

Location: `/etc/easypanel/config`

```bash
# View configuration
cat /etc/easypanel/config

# Edit configuration
sudo nano /etc/easypanel/config
```

### Web Server Configuration

**Nginx:**
```bash
# Global configuration
/etc/nginx/nginx.conf

# Domain-specific
/etc/nginx/sites-available/domain.com
```

**Apache2:**
```bash
# Global configuration
/etc/apache2/apache2.conf

# Domain-specific
/etc/apache2/sites-available/domain.com.conf
```

### Database Configuration

**MariaDB/MySQL:**
```bash
# Main configuration
/etc/mysql/my.cnf
or
/etc/mariadb/my.cnf

# Database root password
# Default: root (Please change this!)
```

## Common Tasks

### Add a New Domain

```bash
sudo easypanel
# Select: 2) Manage Domains
# Select: 2) Add Domain
# Follow prompts
```

### Create a Database

```bash
sudo easypanel databases
# Select: 2) Create Database
# Enter database name
# Create database user
```

### Set Up Mail Account

```bash
sudo easypanel mail
# Select: 2) Add Mail Account
# Enter email address
# Configure DKIM, SMTP relay, Roundcube
```

### Backup Website

```bash
sudo easypanel backup
# Select: 1) Backup Websites
# Choose specific domain or all domains
```

### Schedule Automatic Backups

```bash
sudo easypanel cron
# Select: 2) Add Cron Job
# Select backup option
# Choose schedule
```

### Renew SSL Certificate

```bash
sudo easypanel domains
# Select: 3) Edit Domain
# Select: 4) Renew SSL certificate
```

### View System Status

```bash
sudo easypanel status
```

## Troubleshooting

### Connection Issues

```bash
# Check if web server is running
sudo systemctl status nginx
# or
sudo systemctl status apache2

# Check if database is running
sudo systemctl status mysql
# or
sudo systemctl status mariadb

# Restart services
sudo systemctl restart nginx
sudo systemctl restart mysql
```

### Permission Issues

```bash
# Fix website directory permissions
sudo chown -R www-data:www-data /root/websites/domain.com
sudo chmod -R 755 /root/websites/domain.com
```

### SSL Certificate Issues

```bash
# Check certificate validity
sudo openssl x509 -in /etc/letsencrypt/live/domain.com/cert.pem -text -noout

# Renew certificates
sudo certbot renew

# Force renewal
sudo certbot renew --force-renewal
```

### Database Issues

```bash
# Connect to database
sudo mysql -u root -p

# Check database size
mysql -u root -p -e "SELECT table_schema 'Database', ROUND(SUM(data_length+index_length)/1024/1024,2) 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;"

# Optimize database
sudo mysqlcheck -u root -p --optimize --all-databases
```

### View Logs

```bash
# EasyPanel logs
sudo tail -f /var/log/easypanel.log

# Web server logs
sudo tail -f /root/websites/domain.com/logs/error.log

# Nginx errors
sudo tail -f /var/log/nginx/error.log

# Apache2 errors
sudo tail -f /var/log/apache2/error.log
```

## Updates

### Check for Updates

```bash
sudo apt update
apt list --upgradable | grep easypanel
```

### Install Updates

```bash
sudo apt update
sudo apt install easypanel
```

## Uninstall

```bash
sudo apt remove easypanel
```

This will remove EasyPanel but keep your data intact.

## Configuration Backup

```bash
# Backup everything
sudo tar -czf ~/easypanel_backup_$(date +%Y%m%d).tar.gz \
  /root/websites \
  /root/backups \
  /etc/easypanel

# Restore from backup
sudo tar -xzf ~/easypanel_backup_*.tar.gz -C /
```

## Security Recommendations

1. **Change Database Root Password**
   ```bash
   sudo easypanel
   # Settings → Change Database Password
   ```

2. **Enable Firewall**
   ```bash
   sudo easypanel
   # Settings → Firewall Configuration
   ```

3. **Install SSL Certificates**
   ```bash
   sudo easypanel domains
   # Edit domain → Install SSL certificate
   ```

4. **Enable Automatic Updates**
   ```bash
   sudo easypanel cron
   # Add Cron Job → System update check
   ```

5. **Regular Backups**
   ```bash
   sudo easypanel backup
   # Schedule Automatic Backups
   ```

## Support

- **Documentation**: [GitHub Wiki](https://github.com/easypanel/easypanel/wiki)
- **Issues**: [GitHub Issues](https://github.com/easypanel/easypanel/issues)
- **Discussions**: [GitHub Discussions](https://github.com/easypanel/easypanel/discussions)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

EasyPanel is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

## Roadmap

- [ ] Web-based interface
- [ ] Multi-server management
- [ ] Advanced analytics and monitoring
- [ ] Email notification system
- [ ] Two-factor authentication
- [ ] API interface
- [ ] Mobile app
- [ ] Automatic scaling
- [ ] Container support (Docker)
- [ ] Kubernetes integration

## Changelog

### v1.0.0 (2025-01-01)
- Initial release
- Full domain management
- Database management
- Mail server integration
- DNS management
- Backup and restore
- Cron job scheduling
- Security features

## Frequently Asked Questions (FAQ)

**Q: Can I use EasyPanel with an existing web server?**
A: Yes, but you'll need to migrate your configuration. Run the installation wizard and it will detect existing installations.

**Q: How do I migrate from Apache2 to Nginx?**
A: Run `sudo easypanel install`, choose to remove and reinstall, then select Nginx. Your domains and data will remain intact.

**Q: Can I manage multiple servers with EasyPanel?**
A: Currently, EasyPanel manages a single server. Multi-server support is planned for future versions.

**Q: Is there a web interface?**
A: Not yet, but a web interface is planned for future versions.

**Q: How often should I backup?**
A: We recommend daily backups for production servers. Use `sudo easypanel cron` to schedule automatic backups.

**Q: Can I use EasyPanel on VPS/Cloud servers?**
A: Yes, EasyPanel works on any Debian/Ubuntu server.

---

**Version:** 1.0.0  
**Last Updated:** January 2025  
**Website:** https://github.com/easypanel/easypanel
