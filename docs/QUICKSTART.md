# Quick Start Guide - EasyPanel

## Step 1: Install EasyPanel

```bash
# Install from package
sudo apt install -y ./easypanel_1.0.0_all.deb

# Or use curl to download and install
curl -sSL https://installer.easypanel.io | sudo bash
```

## Step 2: Initial Setup

```bash
# Run the installation wizard
sudo easypanel install
```

**The wizard will ask:**
1. Choose web server: Apache2 or Nginx
2. Choose database: MySQL or MariaDB
3. PHP versions (latest or multiple versions)
4. Install mail server? (optional)
5. Install DNS server? (optional)
6. Install firewall? (optional)

## Step 3: Add Your First Domain

```bash
sudo easypanel
```

**Select:** 2) Manage Domains → 2) Add Domain

**You'll be asked:**
- Domain name: `example.com`
- Add DNS support? (Yes/No)
- Add mail support? (Yes/No)
- Install SSL certificate? (Yes)

**Upload your website files to:**
```
/root/websites/example.com/htdocs/
```

## Step 4: Create a Database

```bash
sudo easypanel
```

**Select:** 5) Manage Databases → 2) Create Database

**Enter:**
- Database name: `example_db`
- Create user? (Yes)
- Username: `example_user`
- Password: (choose strong password)

## Step 5: Access Your Website

```
http://example.com
https://example.com  (SSL)
```

## Common Next Steps

### Add Mail Support
```bash
sudo easypanel → 4) Manage Mail → 2) Add Mail Account
```

### Configure DNS
```bash
sudo easypanel → 3) Manage DNS → 2) Create DNS Zone
```

### Schedule Backups
```bash
sudo easypanel → 6) Manage Cron Jobs → 2) Add Cron Job → 1) Website backup
```

### View System Status
```bash
sudo easypanel status
```

## Important Notes

1. **Change Database Password**: Run `sudo easypanel` → Settings → Change Database Password
2. **Enable Firewall**: Run `sudo easypanel` → Settings → Firewall Configuration
3. **Set Up Backups**: Regular backups are crucial for production servers
4. **Monitor Logs**: Check `/var/log/easypanel.log` for issues

## Support

- **Full Documentation**: Run `easypanel help` or see docs/README.md
- **Report Issues**: github.com/easypanel/easypanel/issues
- **Ask Questions**: github.com/easypanel/easypanel/discussions

## Troubleshooting

**Website not loading?**
```bash
# Check web server
sudo systemctl status nginx
# or
sudo systemctl status apache2

# Check logs
sudo tail -f /root/websites/example.com/logs/error.log
```

**Database connection error?**
```bash
# Check database
sudo systemctl status mysql
# Check credentials
sudo mysql -u root -p
```

**SSL certificate not working?**
```bash
# Check certificate
sudo openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout

# Renew certificate
sudo certbot renew
```

---

**Next:** Read the full documentation in `docs/README.md`
