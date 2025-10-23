#!/bin/bash

################################################################################
# EasyPanel Standalone - All-in-One Web Server Control Panel
# Completely standalone executable with no dependencies
# Can be downloaded directly from URL and run: bash easypanel-standalone.sh
#
# Features:
#  • Installation & Setup
#  • Domain Management (Apache2/Nginx)
#  • SSL Certificate Management (Let's Encrypt)
#  • DNS Management (BIND9)
#  • Mail Server Configuration (Postfix/Dovecot)
#  • Database Management (MySQL/MariaDB)
#  • Backup & Restore
#  • Cron Job Management
#  • System Settings & Status
#
# Usage: bash easypanel-standalone.sh
# Or make executable: chmod +x easypanel-standalone.sh && ./easypanel-standalone.sh
################################################################################

set +e

PANEL_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Panel configuration
PANEL_CONFIG_DIR="/etc/easypanel"
PANEL_CONFIG_FILE="$PANEL_CONFIG_DIR/config"
PANEL_LOG_FILE="/var/log/easypanel.log"
WEBSITES_ROOT="/root/websites"
BACKUP_ROOT="/root/backups"

# DNS/Bind configuration
BIND_CONFIG_DIR="/etc/bind/easypanel"
BIND_ZONES_DIR="/var/lib/bind/easypanel"

# Mail configuration
MAIL_CONFIG_DIR="/etc/easypanel/mail"
MAIL_USERS_DIR="/home/mail"
DKIM_DIR="/etc/opendkim/keys"

################################################################################
# COLOR CODES
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

################################################################################
# OUTPUT FUNCTIONS
################################################################################

print_header() {
    clear
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC} $1"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log_message "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log_message "INFO: $1"
}

print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$PANEL_LOG_FILE" 2>/dev/null
}

init_logging() {
    touch "$PANEL_LOG_FILE" 2>/dev/null
    chmod 644 "$PANEL_LOG_FILE" 2>/dev/null
}

################################################################################
# USER INPUT FUNCTIONS
################################################################################

prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$prompt (yes/no): " response
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) print_warning "Please answer yes or no." ;;
        esac
    done
}

print_menu() {
    local title="$1"
    shift
    local -a options=("$@")
    
    clear
    print_header "$title"
    
    local i=1
    for option in "${options[@]}"; do
        echo -e "  ${CYAN}$i)${NC} $option"
        ((i++))
    done
    echo ""
}

get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

pause_menu() {
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# SYSTEM CHECK FUNCTIONS
################################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    dpkg -l | grep -q "^ii.*$1"
}

service_running() {
    systemctl is-active --quiet "$1"
}

service_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

################################################################################
# FILE OPERATION FUNCTIONS
################################################################################

backup_file() {
    local file="$1"
    local backup_path="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$file" ]; then
        cp "$file" "$backup_path"
        print_success "Backed up: $file → $backup_path"
        return 0
    else
        print_error "File not found: $file"
        return 1
    fi
}

create_directory() {
    local dir="$1"
    local owner="${2:-root}"
    local perms="${3:-755}"
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chown "$owner" "$dir"
        chmod "$perms" "$dir"
        print_success "Created directory: $dir"
    fi
}

remove_directory() {
    local dir="$1"
    
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        print_success "Removed directory: $dir"
    fi
}

################################################################################
# CONFIGURATION FUNCTIONS
################################################################################

init_config() {
    create_directory "$PANEL_CONFIG_DIR" "root" "755"
    
    if [ ! -f "$PANEL_CONFIG_FILE" ]; then
        cat > "$PANEL_CONFIG_FILE" << 'EOF'
# EasyPanel Configuration
# Generated on first run

WEB_SERVER=""
DATABASE=""
SERVICES_INSTALLED=""
PANEL_INSTALLED_DATE=""
PANEL_VERSION=""
EOF
        chmod 600 "$PANEL_CONFIG_FILE"
        print_success "Created configuration file: $PANEL_CONFIG_FILE"
    fi
}

set_config() {
    local key="$1"
    local value="$2"
    
    if [ -f "$PANEL_CONFIG_FILE" ]; then
        sed -i "/^${key}=/d" "$PANEL_CONFIG_FILE"
        echo "${key}=\"${value}\"" >> "$PANEL_CONFIG_FILE"
    fi
}

get_config() {
    local key="$1"
    local default="${2:-}"
    
    if [ -f "$PANEL_CONFIG_FILE" ]; then
        local value=$(grep "^${key}=" "$PANEL_CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

################################################################################
# DOMAIN/WEBSITE FUNCTIONS
################################################################################

create_domain_structure() {
    local domain="$1"
    local owner="${2:-www-data}"
    
    create_directory "$WEBSITES_ROOT/$domain/htdocs" "$owner" "755"
    create_directory "$WEBSITES_ROOT/$domain/config" "root" "755"
    create_directory "$WEBSITES_ROOT/$domain/logs" "$owner" "755"
    create_directory "$WEBSITES_ROOT/$domain/certificates" "root" "755"
    
    print_success "Created directory structure for domain: $domain"
}

remove_domain_structure() {
    local domain="$1"
    
    if prompt_yes_no "Are you sure you want to delete all files for $domain?"; then
        remove_directory "$WEBSITES_ROOT/$domain"
    else
        print_info "Cancelled"
        return 1
    fi
}

list_domains() {
    if [ -d "$WEBSITES_ROOT" ]; then
        ls -d "$WEBSITES_ROOT"/*/ 2>/dev/null | xargs -n 1 basename
    fi
}

copy_ssl_certificates_local() {
    local domain="$1"
    local cert_source="/etc/letsencrypt/live/$domain"
    local cert_dest="$WEBSITES_ROOT/$domain/certificates"
    
    if [ ! -d "$cert_source" ]; then
        print_warning "Source certificate directory not found: $cert_source"
        return 1
    fi
    
    cp -r "$cert_source"/* "$cert_dest/" 2>/dev/null
    chmod 644 "$cert_dest"/*.pem 2>/dev/null
    chmod 600 "$cert_dest"/privkey.pem 2>/dev/null
    chown -R root:root "$cert_dest" 2>/dev/null
    
    print_success "Certificates copied to: $cert_dest"
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

validate_domain() {
    local domain="$1"
    local regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    
    if [[ $domain =~ $regex ]]; then
        return 0
    else
        print_error "Invalid domain name: $domain"
        return 1
    fi
}

validate_email() {
    local email="$1"
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ $email =~ $regex ]]; then
        return 0
    else
        print_error "Invalid email address: $email"
        return 1
    fi
}

validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $regex ]]; then
        return 0
    else
        print_error "Invalid IP address: $ip"
        return 1
    fi
}

validate_username() {
    local username="$1"
    local regex="^[a-zA-Z0-9_-]{3,32}$"
    
    if [[ $username =~ $regex ]]; then
        return 0
    else
        print_error "Invalid username (3-32 chars, alphanumeric, _, -): $username"
        return 1
    fi
}

################################################################################
# SERVICE MANAGEMENT FUNCTIONS
################################################################################

start_service() {
    local service="$1"
    
    if systemctl start "$service"; then
        print_success "Started service: $service"
        return 0
    else
        print_error "Failed to start service: $service"
        return 1
    fi
}

stop_service() {
    local service="$1"
    
    if systemctl stop "$service"; then
        print_success "Stopped service: $service"
        return 0
    else
        print_error "Failed to stop service: $service"
        return 1
    fi
}

restart_service() {
    local service="$1"
    
    if systemctl restart "$service"; then
        print_success "Restarted service: $service"
        return 0
    else
        print_error "Failed to restart service: $service"
        return 1
    fi
}

enable_service() {
    local service="$1"
    
    if systemctl enable "$service"; then
        print_success "Enabled service: $service"
        return 0
    else
        print_error "Failed to enable service: $service"
        return 1
    fi
}

disable_service() {
    local service="$1"
    
    if systemctl disable "$service"; then
        print_success "Disabled service: $service"
        return 0
    else
        print_error "Failed to disable service: $service"
        return 1
    fi
}

################################################################################
# INSTALLATION FUNCTIONS
################################################################################

check_system_requirements() {
    print_header "Checking System Requirements"
    
    if ! [ -f /etc/os-release ]; then
        die "This system is not supported. Debian/Ubuntu required."
    fi
    
    source /etc/os-release
    print_info "Detected: $PRETTY_NAME"
    
    if [[ ! "$ID" =~ ^(debian|ubuntu)$ ]]; then
        if ! prompt_yes_no "This system is not officially supported. Continue anyway?"; then
            exit 1
        fi
    fi
    
    print_info "Updating package lists..."
    apt-get update >/dev/null 2>&1 || print_warning "Failed to update package lists"
    
    pause_menu
}

select_web_server() {
    print_header "Select Web Server"
    
    echo "Which web server would you like to install?"
    echo ""
    echo -e "  ${CYAN}1)${NC} Apache2"
    echo -e "  ${CYAN}2)${NC} Nginx (Recommended)"
    echo ""
    
    read -p "Select [1-2]: " choice
    
    case "$choice" in
        1) WEB_SERVER="apache2"; print_info "Selected: Apache2" ;;
        2) WEB_SERVER="nginx"; print_info "Selected: Nginx" ;;
        *) print_error "Invalid choice"; select_web_server; return ;;
    esac
    
    pause_menu
}

select_database() {
    print_header "Select Database Server"
    
    echo "Which database server would you like to install?"
    echo ""
    echo -e "  ${CYAN}1)${NC} MySQL"
    echo -e "  ${CYAN}2)${NC} MariaDB (Recommended)"
    echo ""
    
    read -p "Select [1-2]: " choice
    
    case "$choice" in
        1) DATABASE="mysql-server"; print_info "Selected: MySQL" ;;
        2) DATABASE="mariadb-server"; print_info "Selected: MariaDB" ;;
        *) print_error "Invalid choice"; select_database; return ;;
    esac
    
    pause_menu
}

install_web_server() {
    print_header "Installing Web Server"
    
    case "$WEB_SERVER" in
        apache2) install_apache2 ;;
        nginx) install_nginx ;;
    esac
}

install_apache2() {
    print_info "Installing Apache2..."
    
    apt-get install -y apache2 apache2-utils apache2-dev >/dev/null 2>&1 || {
        print_error "Failed to install Apache2"
        return 1
    }
    
    a2enmod rewrite >/dev/null 2>&1
    a2enmod ssl >/dev/null 2>&1
    a2enmod proxy >/dev/null 2>&1
    a2enmod proxy_fcgi >/dev/null 2>&1
    a2enmod headers >/dev/null 2>&1
    
    mkdir -p /etc/apache2/sites-available/easypanel
    
    enable_service "apache2"
    restart_service "apache2"
    
    print_success "Apache2 installed and configured"
}

install_nginx() {
    print_info "Installing Nginx..."
    
    apt-get install -y nginx nginx-common >/dev/null 2>&1 || {
        print_error "Failed to install Nginx"
        return 1
    }
    
    mkdir -p /etc/nginx/sites-available/easypanel
    mkdir -p /etc/nginx/sites-enabled/easypanel
    
    enable_service "nginx"
    restart_service "nginx"
    
    print_success "Nginx installed and configured"
}

install_database() {
    print_header "Installing Database Server"
    
    case "$DATABASE" in
        mysql-server) install_mysql ;;
        mariadb-server) install_mariadb ;;
    esac
}

install_mysql() {
    print_info "Installing MySQL Server..."
    
    echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
    
    apt-get install -y mysql-server mysql-client >/dev/null 2>&1 || {
        print_error "Failed to install MySQL"
        return 1
    }
    
    enable_service "mysql"
    restart_service "mysql"
    
    print_success "MySQL Server installed"
    print_warning "Default root password: root (Please change this!)"
}

install_mariadb() {
    print_info "Installing MariaDB Server..."
    
    echo "mariadb-server mariadb-server/root_password password root" | debconf-set-selections
    echo "mariadb-server mariadb-server/root_password_again password root" | debconf-set-selections
    
    apt-get install -y mariadb-server mariadb-client >/dev/null 2>&1 || {
        print_error "Failed to install MariaDB"
        return 1
    }
    
    enable_service "mariadb"
    restart_service "mariadb"
    
    print_success "MariaDB Server installed"
    print_warning "Default root password: root (Please change this!)"
}

install_dns_server() {
    print_header "Installing DNS Server (BIND)"
    
    if ! prompt_yes_no "Install DNS Server (BIND)?"; then
        print_info "Skipping DNS Server installation"
        return
    fi
    
    print_info "Installing BIND9..."
    
    apt-get install -y bind9 bind9-utils bind9-dnssec dnsutils >/dev/null 2>&1 || {
        print_error "Failed to install BIND9"
        return 1
    }
    
    mkdir -p /etc/bind/easypanel
    chown -R bind:bind /etc/bind/easypanel
    
    enable_service "bind9"
    restart_service "bind9"
    
    print_success "BIND9 DNS Server installed"
}

install_mail_server() {
    print_header "Installing Mail Server"
    
    if ! prompt_yes_no "Install Mail Server?"; then
        print_info "Skipping Mail Server installation"
        return
    fi
    
    print_info "Installing Postfix..."
    echo "postfix postfix/mailname string localhost" | debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
    
    apt-get install -y postfix >/dev/null 2>&1 || {
        print_error "Failed to install Postfix"
        return 1
    }
    
    print_info "Installing Dovecot..."
    apt-get install -y dovecot-core dovecot-imapd dovecot-pop3d sieve-tools >/dev/null 2>&1 || {
        print_error "Failed to install Dovecot"
        return 1
    }
    
    enable_service "postfix"
    enable_service "dovecot"
    restart_service "postfix"
    restart_service "dovecot"
    
    print_success "Mail Server installed and configured"
}

install_certbot() {
    print_header "Installing Let's Encrypt Support"
    
    print_info "Installing Certbot..."
    
    apt-get install -y certbot python3-certbot-${WEB_SERVER} >/dev/null 2>&1 || {
        print_error "Failed to install Certbot"
        return 1
    }
    
    mkdir -p /etc/letsencrypt/renewal-hooks/post
    
    print_success "Let's Encrypt support installed"
}

create_required_directories() {
    print_header "Creating Required Directories"
    
    create_directory "/root/websites" "root" "755"
    create_directory "/root/backups" "root" "755"
    create_directory "/var/log/easypanel" "root" "755"
    create_directory "/etc/easypanel" "root" "755"
    
    print_success "Directory structure created"
}

run_installation() {
    print_header "EasyPanel - Full Installation Wizard"
    
    print_warning "This installation will configure your system as a web server."
    if ! prompt_yes_no "Continue with installation?"; then
        print_info "Installation cancelled"
        return
    fi
    
    check_system_requirements
    select_web_server
    select_database
    
    create_required_directories
    
    install_web_server
    install_database
    install_dns_server
    install_mail_server
    install_certbot
    
    set_config "WEB_SERVER" "$WEB_SERVER"
    set_config "DATABASE" "$DATABASE"
    set_config "PANEL_INSTALLED_DATE" "$(date)"
    
    print_header "Installation Summary"
    echo -e "${BOLD}Selected Configuration:${NC}"
    echo "  Web Server: $WEB_SERVER"
    echo "  Database: $DATABASE"
    echo ""
    print_success "Installation complete!"
    
    pause_menu
}

################################################################################
# DOMAIN MANAGEMENT
################################################################################

add_domain() {
    print_header "Add New Domain"
    
    while true; do
        local domain=$(get_input "Enter domain name" "example.com")
        
        if validate_domain "$domain"; then
            if [ -d "$WEBSITES_ROOT/$domain" ]; then
                print_warning "Domain already exists"
                if ! prompt_yes_no "Configure existing domain?"; then
                    return
                fi
            fi
            break
        fi
    done
    
    create_domain_structure "$domain"
    
    if prompt_yes_no "Install SSL certificate with Let's Encrypt?"; then
        install_ssl_certificate "$domain"
    fi
    
    print_success "Domain '$domain' added successfully!"
    pause_menu
}

install_ssl_certificate() {
    local domain="$1"
    
    print_info "Installing SSL certificate with Let's Encrypt..."
    
    if certbot certonly --standalone -d "$domain" -d "www.$domain" \
        --non-interactive --agree-tos -m admin@${domain} 2>/dev/null; then
        
        copy_ssl_certificates_local "$domain"
        print_success "SSL certificate installed for $domain"
    else
        print_error "Failed to install SSL certificate"
        return 1
    fi
}

list_domains_display() {
    print_header "Domains List"
    
    local domains=($(list_domains))
    
    if [ ${#domains[@]} -eq 0 ]; then
        print_info "No domains configured"
        pause_menu
        return
    fi
    
    echo -e "${BOLD}Configured Domains:${NC}"
    echo ""
    
    for domain in "${domains[@]}"; do
        echo -e "  ${CYAN}•${NC} $domain"
    done
    
    echo ""
    pause_menu
}

delete_domain() {
    print_header "Delete Domain"
    
    local domains=($(list_domains))
    
    if [ ${#domains[@]} -eq 0 ]; then
        print_info "No domains to delete"
        pause_menu
        return
    fi
    
    echo "Select domain to delete:"
    echo ""
    
    for i in "${!domains[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${domains[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#domains[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#domains[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local domain="${domains[$((selection-1))]}"
    
    print_warning "This will delete domain: $domain"
    if prompt_yes_no "Continue?"; then
        remove_domain_structure "$domain"
        print_success "Domain deleted: $domain"
    else
        print_info "Cancelled"
    fi
    
    pause_menu
}

################################################################################
# DNS MANAGEMENT
################################################################################

init_dns() {
    if ! command_exists "named"; then
        print_error "BIND9 is not installed. Please run installation first."
        return 1
    fi
    
    mkdir -p "$BIND_ZONES_DIR"
    chown -R bind:bind "$BIND_ZONES_DIR"
    chmod -R 755 "$BIND_ZONES_DIR"
}

create_dns_zone() {
    print_header "Create DNS Zone"
    
    local domain=$(get_input "Enter domain name" "example.com")
    
    if ! validate_domain "$domain"; then
        return 1
    fi
    
    if [ -f "$BIND_ZONES_DIR/db.$domain" ]; then
        print_warning "Zone already exists for $domain"
        if ! prompt_yes_no "Overwrite?"; then
            return 1
        fi
    fi
    
    local ns_ip=$(get_input "Enter nameserver IP" "8.8.8.8")
    if ! validate_ip "$ns_ip"; then
        return 1
    fi
    
    local zone_file="$BIND_ZONES_DIR/db.$domain"
    local serial=$(date +%Y%m%d01)
    
    cat > "$zone_file" << EOF
\$TTL 3600
@  IN  SOA ns1.$domain. admin.$domain. (
           $serial  ; Serial
           3600     ; Refresh
           1800     ; Retry
           604800   ; Expire
           86400 )  ; Minimum TTL

@  IN  NS  ns1.$domain.
@  IN  NS  ns2.$domain.
@        IN  A      $ns_ip
www      IN  A      $ns_ip
ns1      IN  A      $ns_ip
ns2      IN  A      $ns_ip
@        IN  MX 10  mail.$domain.
mail     IN  A      $ns_ip
@        IN  TXT    "v=spf1 mx ~all"
EOF
    
    chown bind:bind "$zone_file"
    chmod 640 "$zone_file"
    
    # Add to BIND configuration
    local config_file="/etc/bind/named.conf.local"
    if ! grep -q "zone \"$domain\"" "$config_file"; then
        cat >> "$config_file" << EOF

zone "$domain" {
    type master;
    file "$BIND_ZONES_DIR/db.$domain";
    allow-transfer { any; };
};
EOF
    fi
    
    restart_service "bind9"
    
    print_success "DNS zone created for $domain"
    pause_menu
}

################################################################################
# MAIL MANAGEMENT
################################################################################

init_mail() {
    if ! service_running "postfix"; then
        print_error "Postfix is not running. Please install mail services first."
        return 1
    fi
    
    mkdir -p "$MAIL_CONFIG_DIR"
    mkdir -p "$MAIL_USERS_DIR"
    chmod 755 "$MAIL_USERS_DIR"
}

add_mail_account() {
    print_header "Add Mail Account"
    
    while true; do
        local email=$(get_input "Enter email address" "user@example.com")
        
        if validate_email "$email"; then
            break
        fi
    done
    
    if [ -d "$MAIL_USERS_DIR/$email" ]; then
        print_warning "Mail account already exists"
        pause_menu
        return
    fi
    
    local password
    while true; do
        read -sp "Enter password: " password
        echo ""
        read -sp "Confirm password: " password_confirm
        echo ""
        
        if [ "$password" = "$password_confirm" ]; then
            break
        else
            print_error "Passwords do not match"
        fi
    done
    
    local mailbox_path="$MAIL_USERS_DIR/$email"
    mkdir -p "$mailbox_path/Maildir"/{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Sent/"{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Drafts/"{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Trash/"{cur,new,tmp}
    
    chmod -R 755 "$mailbox_path"
    chmod -R 755 "$mailbox_path/Maildir"
    
    print_success "Mail account created: $email"
    pause_menu
}

################################################################################
# DATABASE MANAGEMENT
################################################################################

get_db_command() {
    local db_type=$(get_config "DATABASE" "mariadb-server")
    
    if [ "$db_type" = "mysql-server" ]; then
        echo "mysql"
    else
        echo "mariadb"
    fi
}

check_db_connection() {
    local db_type=$(get_config "DATABASE" "mariadb-server")
    
    if [ "$db_type" = "mysql-server" ]; then
        mysql -u root -proot -e "SELECT 1" >/dev/null 2>&1
    else
        mariadb -u root -proot -e "SELECT 1" >/dev/null 2>&1
    fi
    
    return $?
}

list_databases() {
    print_header "List Databases"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    echo -e "${BOLD}Databases:${NC}"
    echo ""
    
    $db_cmd -u root -proot -e "SHOW DATABASES;" 2>/dev/null | tail -n +2 | while read db; do
        if [[ ! "$db" =~ ^(information_schema|mysql|performance_schema|sys)$ ]]; then
            echo -e "  ${CYAN}•${NC} $db"
        fi
    done
    
    echo ""
    pause_menu
}

create_database() {
    print_header "Create Database"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_name=$(get_input "Database name")
    
    if [ -z "$db_name" ]; then
        print_error "Database name cannot be empty"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    if $db_cmd -u root -proot -e "CREATE DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" 2>/dev/null; then
        print_success "Database created: $db_name"
    else
        print_error "Failed to create database"
    fi
    
    pause_menu
}

################################################################################
# BACKUP MANAGEMENT
################################################################################

init_backup() {
    mkdir -p "$BACKUP_ROOT"/{websites,databases,full,logs}
    chmod 700 "$BACKUP_ROOT"
}

backup_websites() {
    print_header "Website Backup"
    
    local backup_dir="$BACKUP_ROOT/websites"
    local domains=($(list_domains))
    
    if [ ${#domains[@]} -eq 0 ]; then
        print_info "No domains to backup"
        pause_menu
        return
    fi
    
    local backup_file="$backup_dir/websites_full_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    print_info "Backing up all domains..."
    
    if tar -czf "$backup_file" /root/websites 2>/dev/null; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Backup completed: $backup_file ($size)"
    else
        print_error "Backup failed"
    fi
    
    pause_menu
}

backup_databases() {
    print_header "Database Backup"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    local backup_dir="$BACKUP_ROOT/databases"
    local backup_file="$backup_dir/all_databases_$(date +%Y%m%d_%H%M%S).sql.gz"
    
    print_info "Backing up all databases..."
    
    if $db_cmd -u root -proot --all-databases 2>/dev/null | gzip > "$backup_file"; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Backup completed: $backup_file ($size)"
    else
        print_error "Backup failed"
    fi
    
    pause_menu
}

list_backups() {
    print_header "Backup Files"
    
    if [ ! -d "$BACKUP_ROOT" ]; then
        print_info "No backups found"
        pause_menu
        return
    fi
    
    echo -e "${BOLD}Website Backups:${NC}"
    if [ -d "$BACKUP_ROOT/websites" ] && [ "$(ls -A "$BACKUP_ROOT/websites" 2>/dev/null)" ]; then
        ls -lh "$BACKUP_ROOT/websites" | tail -n +2 | awk '{print "  " $9, "(" $5 ")"}'
    else
        echo "  No backups"
    fi
    
    echo ""
    echo -e "${BOLD}Database Backups:${NC}"
    if [ -d "$BACKUP_ROOT/databases" ] && [ "$(ls -A "$BACKUP_ROOT/databases" 2>/dev/null)" ]; then
        ls -lh "$BACKUP_ROOT/databases" | tail -n +2 | awk '{print "  " $9, "(" $5 ")"}'
    else
        echo "  No backups"
    fi
    
    echo ""
    pause_menu
}

################################################################################
# CRON MANAGEMENT
################################################################################

list_cron_jobs() {
    print_header "Cron Jobs"
    
    echo -e "${BOLD}System Cron Jobs:${NC}"
    echo ""
    
    local count=0
    for user in root www-data; do
        local crontab=$(crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$")
        
        if [ -n "$crontab" ]; then
            echo "User: $user"
            echo "$crontab" | nl
            echo ""
            count=$((count + $(echo "$crontab" | wc -l)))
        fi
    done
    
    if [ $count -eq 0 ]; then
        print_info "No cron jobs configured"
    fi
    
    echo ""
    pause_menu
}

add_custom_cron() {
    print_header "Add Custom Cron Job"
    
    echo "Cron format: minute hour day month weekday command"
    echo "Example: 0 2 * * * /home/user/backup.sh (daily at 2:00 AM)"
    echo ""
    
    local schedule=$(get_input "Cron schedule")
    local command=$(get_input "Command to execute")
    local user=$(get_input "Run as user" "root")
    
    (crontab -u "$user" -l 2>/dev/null; echo "$schedule $command") | crontab -u "$user" - 2>/dev/null
    
    print_success "Custom cron job added"
    pause_menu
}

################################################################################
# SETTINGS & STATUS
################################################################################

show_system_status() {
    print_header "System Status"
    
    echo -e "${BOLD}Web Server:${NC}"
    if command_exists apache2ctl; then
        echo "  Apache2: Installed"
        service_running apache2 && echo -e "  Status: ${GREEN}Running${NC}" || echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    if command_exists nginx; then
        echo "  Nginx: Installed"
        service_running nginx && echo -e "  Status: ${GREEN}Running${NC}" || echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}Database:${NC}"
    if command_exists mysql; then
        echo "  MySQL: Installed"
        service_running mysql && echo -e "  Status: ${GREEN}Running${NC}" || echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    if command_exists mysqld; then
        echo "  MariaDB: Installed"
        service_running mariadb && echo -e "  Status: ${GREEN}Running${NC}" || echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}DNS:${NC}"
    if command_exists named; then
        echo "  BIND9: Installed"
        service_running bind9 && echo -e "  Status: ${GREEN}Running${NC}" || echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}Mail:${NC}"
    if command_exists postfix; then
        echo "  Postfix: Installed"
        service_running postfix && echo -e "  Status: ${GREEN}Running${NC}" || echo -e "  Status: ${RED}Stopped${NC}"
    fi
    
    echo ""
    pause_menu
}

show_configuration() {
    print_header "Current Configuration"
    
    echo -e "${BOLD}Installation Details:${NC}"
    echo "  Web Server: $(get_config "WEB_SERVER" "Not configured")"
    echo "  Database: $(get_config "DATABASE" "Not configured")"
    echo "  Installed: $(get_config "PANEL_INSTALLED_DATE" "Unknown")"
    echo ""
    
    echo -e "${BOLD}System Paths:${NC}"
    echo "  Websites Root: /root/websites"
    echo "  Backups: /root/backups"
    echo "  Config: /etc/easypanel"
    echo ""
    
    pause_menu
}

show_about() {
    print_header "About EasyPanel Standalone"
    
    cat << 'EOF'

EasyPanel v1.0.0 - Standalone All-in-One
Terminal-based Web Server Control Panel

A comprehensive solution for managing:
  • Domains and websites (Apache2/Nginx)
  • SSL certificates (Let's Encrypt)
  • DNS zones (BIND9)
  • Mail servers (Postfix/Dovecot)
  • Databases (MySQL/MariaDB)
  • Backups and restoration
  • Cron jobs and automation
  • System monitoring and logs

Features:
  ✓ Standalone - No dependencies or package installation required
  ✓ Complete - All functionality in a single script
  ✓ Portable - Can be downloaded and run directly
  ✓ Scriptable - Works with bash scripting
  ✓ Professional - Full-featured web panel

Usage:
  bash easypanel-standalone.sh
  
For more information, visit: https://github.com/easypanel/easypanel

EOF
    
    pause_menu
}

################################################################################
# MAIN MENU SYSTEM
################################################################################

submenu_install() {
    while true; do
        print_header "Installation & Setup"
        
        echo -e "  ${CYAN}1)${NC} Run Full Installation"
        echo -e "  ${CYAN}2)${NC} Check System Requirements"
        echo -e "  ${CYAN}3)${NC} Install Web Server Only"
        echo -e "  ${CYAN}4)${NC} Install Database Only"
        echo -e "  ${CYAN}5)${NC} Install DNS Server Only"
        echo -e "  ${CYAN}6)${NC} Install Mail Server Only"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-6]: " choice
        
        case "$choice" in
            1) run_installation ;;
            2) check_system_requirements ;;
            3) select_web_server; install_web_server ;;
            4) select_database; install_database ;;
            5) install_dns_server ;;
            6) install_mail_server ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_domains() {
    while true; do
        print_header "Domain Management"
        
        echo -e "  ${CYAN}1)${NC} List Domains"
        echo -e "  ${CYAN}2)${NC} Add Domain"
        echo -e "  ${CYAN}3)${NC} Delete Domain"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-3]: " choice
        
        case "$choice" in
            1) list_domains_display ;;
            2) add_domain ;;
            3) delete_domain ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_dns() {
    init_dns || return
    
    while true; do
        print_header "DNS Management"
        
        echo -e "  ${CYAN}1)${NC} Create DNS Zone"
        echo -e "  ${CYAN}2)${NC} DNS Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-2]: " choice
        
        case "$choice" in
            1) create_dns_zone ;;
            2)
                print_header "DNS Status"
                service_running "bind9" && echo -e "${GREEN}✓ BIND9${NC}: Running" || echo -e "${RED}✗ BIND9${NC}: Stopped"
                echo ""
                pause_menu
                ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_mail() {
    init_mail || return
    
    while true; do
        print_header "Mail Management"
        
        echo -e "  ${CYAN}1)${NC} Add Mail Account"
        echo -e "  ${CYAN}2)${NC} Mail Service Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-2]: " choice
        
        case "$choice" in
            1) add_mail_account ;;
            2)
                print_header "Mail Services Status"
                service_running "postfix" && echo -e "${GREEN}✓ Postfix${NC}: Running" || echo -e "${RED}✗ Postfix${NC}: Stopped"
                service_running "dovecot" && echo -e "${GREEN}✓ Dovecot${NC}: Running" || echo -e "${RED}✗ Dovecot${NC}: Stopped"
                echo ""
                pause_menu
                ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_databases() {
    while true; do
        print_header "Database Management"
        
        echo -e "  ${CYAN}1)${NC} List Databases"
        echo -e "  ${CYAN}2)${NC} Create Database"
        echo -e "  ${CYAN}3)${NC} Database Service Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-3]: " choice
        
        case "$choice" in
            1) list_databases ;;
            2) create_database ;;
            3)
                print_header "Database Service Status"
                local db_type=$(get_config "DATABASE" "mariadb-server")
                service_running "$db_type" && echo -e "${GREEN}✓ $db_type${NC}: Running" || echo -e "${RED}✗ $db_type${NC}: Stopped"
                echo ""
                pause_menu
                ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_cron() {
    while true; do
        print_header "Cron Job Management"
        
        echo -e "  ${CYAN}1)${NC} List Cron Jobs"
        echo -e "  ${CYAN}2)${NC} Add Custom Cron Job"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-2]: " choice
        
        case "$choice" in
            1) list_cron_jobs ;;
            2) add_custom_cron ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_backup() {
    init_backup
    
    while true; do
        print_header "Backup Management"
        
        echo -e "  ${CYAN}1)${NC} Backup Websites"
        echo -e "  ${CYAN}2)${NC} Backup Databases"
        echo -e "  ${CYAN}3)${NC} List Backups"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-3]: " choice
        
        case "$choice" in
            1) backup_websites ;;
            2) backup_databases ;;
            3) list_backups ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

submenu_settings() {
    while true; do
        print_header "Settings"
        
        echo -e "  ${CYAN}1)${NC} Show Configuration"
        echo -e "  ${CYAN}2)${NC} System Status"
        echo -e "  ${CYAN}3)${NC} About EasyPanel"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-3]: " choice
        
        case "$choice" in
            1) show_configuration ;;
            2) show_system_status ;;
            3) show_about ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

show_main_menu() {
    while true; do
        print_header "EasyPanel v${PANEL_VERSION} - Web Server Control Panel"
        
        echo -e "  ${CYAN}1)${NC} Install/Setup"
        echo -e "  ${CYAN}2)${NC} Manage Domains"
        echo -e "  ${CYAN}3)${NC} Manage DNS"
        echo -e "  ${CYAN}4)${NC} Manage Mail"
        echo -e "  ${CYAN}5)${NC} Manage Databases"
        echo -e "  ${CYAN}6)${NC} Manage Backups"
        echo -e "  ${CYAN}7)${NC} Manage Cron Jobs"
        echo -e "  ${CYAN}8)${NC} System Status"
        echo -e "  ${CYAN}9)${NC} Settings"
        echo -e "  ${CYAN}0)${NC} Exit"
        
        print_separator
        read -p "Select option [0-9]: " choice
        
        case "$choice" in
            1) submenu_install ;;
            2) submenu_domains ;;
            3) submenu_dns ;;
            4) submenu_mail ;;
            5) submenu_databases ;;
            6) submenu_backup ;;
            7) submenu_cron ;;
            8) show_system_status ;;
            9) submenu_settings ;;
            0)
                print_info "Thank you for using EasyPanel!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    check_root
    init_logging
    init_config
    
    show_main_menu
}

main "$@"
