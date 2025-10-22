# EasyPanel - Project Overview

## What is EasyPanel?

EasyPanel is a terminal-based control panel for managing web servers on Linux. Similar to Hestia but designed as a complete command-line tool, it provides an intuitive menu-driven interface for managing every aspect of your web server infrastructure.

## Project Structure

```
PANELSV/
├── src/                          # Shell scripts
│   ├── main.sh                  # Main entry point
│   ├── install.sh               # Installation & setup
│   ├── domains.sh               # Domain management
│   ├── dns.sh                   # DNS management
│   ├── mail.sh                  # Mail server management
│   ├── databases.sh             # Database management
│   ├── cron.sh                  # Cron job management
│   ├── backup.sh                # Backup & restore
│   └── settings.sh              # System settings
│
├── lib/
│   └── utils.sh                 # Utility functions library
│
├── debian/                       # Debian package structure
│   ├── DEBIAN/
│   │   ├── control              # Package metadata
│   │   ├── preinst              # Pre-installation script
│   │   ├── postinst             # Post-installation script
│   │   ├── postrm               # Post-removal script
│   │   └── md5sums              # File checksums
│   ├── etc/easypanel/           # Config directory
│   └── usr/local/bin/           # Executable location
│
├── templates/                   # Configuration templates
│   └── easypanel.service        # Systemd service file
│
├── docs/                        # Documentation
│   ├── README.md                # Full documentation
│   └── QUICKSTART.md            # Quick start guide
│
├── build.sh                     # Package build script
└── must_to_have.txt             # Original requirements
```

## Installation Options

### Option 1: Development Installation (Direct)
```bash
cd /path/to/PANELSV
sudo src/main.sh install
```

### Option 2: Build & Install Package
```bash
cd /path/to/PANELSV
sudo bash build.sh
sudo dpkg -i dist/easypanel_1.0.0_all.deb
```

### Option 3: Repository Installation (APT)
```bash
# After setting up repository
sudo apt update
sudo apt install easypanel
```

## Key Features Implemented

### ✅ Completed
- [x] Main menu system with all navigation
- [x] Installation wizard with web server choice (Apache2/Nginx)
- [x] Installation wizard with database choice (MySQL/MariaDB)
- [x] Domain management (add/edit/delete)
- [x] Automatic SSL certificates (Let's Encrypt)
- [x] DNS management (BIND9) with full record support
- [x] Mail server management with DKIM support
- [x] Database management with backup/restore
- [x] Cron job scheduling
- [x] Complete backup system
- [x] Settings and system configuration
- [x] Firewall management (iptables/fail2ban)
- [x] Multi-PHP version support
- [x] Service management and monitoring
- [x] Debian package structure
- [x] Comprehensive documentation

### 🔄 Available for Enhancement
- API interface
- Web-based dashboard (separate project)
- Multi-server management
- Advanced monitoring and analytics
- Email notifications
- Two-factor authentication
- Docker/Kubernetes support
- Mobile application
- Custom plugin system
- Database clustering
- Advanced backup features

## How to Use

### First-Time Installation
```bash
sudo easypanel install
```

### Interactive Menu
```bash
sudo easypanel
```

### Direct Commands
```bash
sudo easypanel install              # Run installation
sudo easypanel domains              # Manage domains
sudo easypanel dns                  # Manage DNS
sudo easypanel mail                 # Manage mail
sudo easypanel databases            # Manage databases
sudo easypanel cron                 # Manage cron jobs
sudo easypanel backup               # Backup & restore
sudo easypanel status               # Show system status
sudo easypanel help                 # Show help
```

## Configuration Files

### Main Configuration
- **Location:** `/etc/easypanel/config`
- **Contains:** Web server choice, database type, installed services

### Web Server
- **Nginx:** `/etc/nginx/sites-available/domain.com`
- **Apache2:** `/etc/apache2/sites-available/domain.com.conf`

### Database
- **MySQL/MariaDB:** `/etc/mysql/my.cnf` or `/etc/mariadb/my.cnf`

### Mail
- **Postfix:** `/etc/postfix/main.cf`
- **Dovecot:** `/etc/dovecot/dovecot.conf`

### DNS
- **BIND9:** `/etc/bind/named.conf.local`
- **Zone Files:** `/var/lib/bind/easypanel/`

## Website Structure

After adding a domain, the following structure is created:

```
/root/websites/
└── example.com/
    ├── htdocs/           # Your website files go here
    │   ├── index.php
    │   ├── .htaccess
    │   └── ...
    ├── config/           # Custom web server configuration
    │   └── custom.conf
    └── logs/             # Access and error logs
        ├── access.log
        └── error.log
```

## Data Storage

### Backups
- **Location:** `/root/backups/`
- **Structure:**
  - `websites/` - Website backups
  - `databases/` - Database backups
  - `full/` - Full system backups
  - `logs/` - Backup logs

### Mail Data
- **Location:** `/home/mail/`
- **Structure:**
  - `user@domain.com/Maildir/` - Mail folders

## Building the Debian Package

### Requirements
```bash
sudo apt install debhelper-compat dpkg-dev
```

### Build Process
```bash
cd /path/to/PANELSV
sudo bash build.sh
```

### Output
```
dist/
├── easypanel_1.0.0_all.deb
└── easypanel_1.0.0_all.deb.sha256
```

### Install from Package
```bash
sudo dpkg -i dist/easypanel_1.0.0_all.deb
```

## Creating a Repository

### Using Aptly (Recommended)

```bash
# Install aptly
sudo apt-get install aptly

# Create repository
aptly repo create -distribution=focal easypanel

# Add package
aptly repo add easypanel dist/easypanel_1.0.0_all.deb

# Publish
aptly publish repo -architectures=all easypanel

# Share published packages
# Add to your repository server at /pub/easypanel
```

### Using Simple HTTP Server

```bash
# Copy to web server
cp -r ~/.aptly/public /var/www/easypanel

# Users can add with:
echo 'deb https://your-domain.com/easypanel focal main' | sudo tee /etc/apt/sources.list.d/easypanel.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys KEY_ID
sudo apt update
sudo apt install easypanel
```

## System Requirements

### Minimum
- Ubuntu 18.04 LTS or Debian 10+
- 512MB RAM
- 500MB disk space
- Root access

### Recommended
- Ubuntu 22.04 LTS or Debian 12+
- 2GB+ RAM
- 5GB+ disk space
- Static IP
- Domain names

## Supported Services

### Web Servers
- Apache2 (with PHP-FPM)
- Nginx (with PHP-FPM)

### Databases
- MySQL Server
- MariaDB Server

### Mail Servers
- Postfix (SMTP)
- Dovecot (IMAP/POP3)
- ClamAV (Antivirus)
- SpamAssassin (Anti-spam)
- Roundcube (Webmail)

### DNS
- BIND9 (Authoritative DNS)

### Security
- Fail2ban (Brute-force protection)
- iptables (Firewall)
- ipset (IP filtering)

### SSL/TLS
- Let's Encrypt (SSL certificates)
- Certbot (Certificate management)

### Scripting
- PHP 5.6, 7.0, 7.1, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4

## Development Notes

### Adding New Features

1. **Create new module script** in `src/`
2. **Source utils.sh** for utility functions
3. **Follow naming conventions:**
   - Menu functions: `{module}_menu()`
   - Operations: `{operation}_{module}()`
4. **Update main.sh** to include new module
5. **Add help documentation**

### Utility Functions Available

See `lib/utils.sh` for complete list:
- Output functions (colors, headers, messages)
- User input functions (prompts, selections)
- System checks (root, packages, services)
- File operations (backup, create, delete)
- Configuration management
- Domain operations
- Error handling
- Service management

### Code Style

- Use 4 spaces for indentation
- Use `local` keyword for variables
- Use descriptive function and variable names
- Include comments for complex logic
- Follow existing patterns

## Troubleshooting Development

### Testing Installation Script
```bash
sudo bash src/install.sh
```

### Testing Main Script
```bash
sudo bash src/main.sh
```

### Testing Specific Module
```bash
source lib/utils.sh
source src/domains.sh
domains_menu
```

### Debugging
```bash
# Enable debug mode
bash -x src/main.sh
```

## Performance Optimization

### For Large Deployments
1. Use Nginx instead of Apache2 (lighter weight)
2. Use MariaDB instead of MySQL (better performance)
3. Enable caching on domains
4. Use CDN for static files
5. Schedule heavy operations during off-peak hours

### Backup Performance
- Compress backups (enabled by default)
- Use incremental backups for large sites
- Schedule during low-traffic periods
- Use fast storage for backups

## Security Best Practices

1. Change database root password immediately
2. Enable firewall rules
3. Install SSL certificates for all domains
4. Keep system updated (schedule auto-updates)
5. Regular backups (daily recommended)
6. Use strong passwords for all accounts
7. Monitor logs regularly
8. Use SSH key authentication (disable password)

## Contributing

To contribute to EasyPanel:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -am 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Create Pull Request

## License

EasyPanel is released under the MIT License.

## Roadmap

### v1.1.0
- [ ] Advanced analytics
- [ ] Email notifications
- [ ] IP blocking UI improvements
- [ ] Better error recovery

### v1.2.0
- [ ] Web-based API
- [ ] Basic web dashboard
- [ ] Custom plugin support

### v2.0.0
- [ ] Web-based full interface
- [ ] Multi-server support
- [ ] Advanced clustering
- [ ] Docker integration

## Support & Resources

- **Documentation:** See `docs/README.md`
- **Quick Start:** See `docs/QUICKSTART.md`
- **Issues:** Report bugs on GitHub
- **Discussions:** Ask questions on GitHub Discussions
- **Wiki:** Check GitHub Wiki for guides

## Authors & Contributors

**EasyPanel Contributors**
- Original concept and development

## Acknowledgments

- Inspired by Hestia Control Panel
- Uses BIND9 for DNS management
- Built for Debian/Ubuntu systems
- Community-driven development

---

**Version:** 1.0.0
**Last Updated:** January 2025
**Repository:** https://github.com/easypanel/easypanel
