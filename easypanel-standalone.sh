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

show_domain_info() {
    local domain="$1"
    
    print_header "Domain Information: $domain"
    
    echo -e "${BOLD}Path:${NC}"
    echo "  $WEBSITES_ROOT/$domain"
    echo ""
    
    echo -e "${BOLD}Subdirectories:${NC}"
    echo "  • htdocs (website files)"
    echo "  • config (custom server configuration)"
    echo "  • logs (access and error logs)"
    echo "  • certificates (SSL certificates)"
    echo ""
    
    echo -e "${BOLD}Web Server:${NC}"
    local web_server=$(get_config "WEB_SERVER")
    echo "  $web_server"
    echo ""
    
    echo -e "${BOLD}SSL Certificate:${NC}"
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        echo -e "  ${GREEN}✓ Installed${NC}"
        local expiry=$(openssl x509 -in "/etc/letsencrypt/live/$domain/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
        echo "  Expires: $expiry"
    else
        echo -e "  ${RED}✗ Not installed${NC}"
    fi
    echo ""
    
    pause_menu
}

edit_domain() {
    print_header "Edit Domain"
    
    local domains=($(list_domains))
    
    if [ ${#domains[@]} -eq 0 ]; then
        print_info "No domains to edit"
        pause_menu
        return
    fi
    
    echo "Select domain to edit:"
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
    
    print_header "Edit Domain: $domain"
    
    echo -e "  ${CYAN}1)${NC} View domain info"
    echo -e "  ${CYAN}2)${NC} Renew SSL certificate"
    echo -e "  ${CYAN}3)${NC} View error log"
    echo -e "  ${CYAN}4)${NC} View access log"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1) show_domain_info "$domain" ;;
        2) renew_ssl_certificate "$domain" ;;
        3) ${EDITOR:-less} "$WEBSITES_ROOT/$domain/logs/error.log" ;;
        4) ${EDITOR:-less} "$WEBSITES_ROOT/$domain/logs/access.log" ;;
        0) return ;;
    esac
}

renew_ssl_certificate() {
    local domain="$1"
    
    print_info "Renewing SSL certificate for $domain..."
    
    if certbot renew --cert-name "$domain" --non-interactive 2>/dev/null; then
        copy_ssl_certificates_local "$domain"
        print_success "SSL certificate renewed for $domain"
    else
        print_error "Failed to renew SSL certificate"
        return 1
    fi
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

list_dns_zones() {
    if [ ! -d "$BIND_ZONES_DIR" ]; then
        return
    fi
    
    ls -1 "$BIND_ZONES_DIR"/db.* 2>/dev/null | xargs -n 1 basename | sed 's/db\.//'
}

list_dns_records() {
    print_header "List DNS Records"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone to view:"
    echo ""
    
    for i in "${!zones[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${zones[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#zones[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#zones[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local zone="${zones[$((selection-1))]}"
    local zone_file="$BIND_ZONES_DIR/db.$zone"
    
    if [ ! -f "$zone_file" ]; then
        print_error "Zone file not found"
        pause_menu
        return
    fi
    
    print_header "DNS Records for $zone"
    cat "$zone_file"
    echo ""
    pause_menu
}

add_dns_record() {
    print_header "Add DNS Record"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone:"
    for i in "${!zones[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${zones[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#zones[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#zones[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local zone="${zones[$((selection-1))]}"
    local zone_file="$BIND_ZONES_DIR/db.$zone"
    
    echo ""
    echo "Select record type:"
    echo -e "  ${CYAN}1)${NC} A Record (IPv4)"
    echo -e "  ${CYAN}2)${NC} CNAME Record"
    echo -e "  ${CYAN}3)${NC} MX Record"
    echo -e "  ${CYAN}4)${NC} TXT Record"
    echo ""
    
    read -p "Select type [1-4]: " type_choice
    
    case "$type_choice" in
        1)
            local name=$(get_input "Enter record name (@ for root, or subdomain)" "@")
            local ip=$(get_input "Enter IPv4 address")
            if validate_ip "$ip"; then
                echo "$name        IN  A      $ip" >> "$zone_file"
                print_success "Added A record: $name -> $ip"
            fi
            ;;
        2)
            local name=$(get_input "Enter CNAME name")
            local target=$(get_input "Enter target domain")
            echo "$name        IN  CNAME  $target." >> "$zone_file"
            print_success "Added CNAME record: $name -> $target"
            ;;
        3)
            local priority=$(get_input "Enter priority (10, 20, etc)" "10")
            local mail_server=$(get_input "Enter mail server hostname")
            echo "@        IN  MX $priority  $mail_server." >> "$zone_file"
            print_success "Added MX record: priority $priority -> $mail_server"
            ;;
        4)
            local name=$(get_input "Enter record name (@ for root)" "@")
            local value=$(get_input "Enter TXT value")
            echo "$name        IN  TXT    \"$value\"" >> "$zone_file"
            print_success "Added TXT record: $name -> $value"
            ;;
    esac
    
    restart_service "bind9"
    pause_menu
}

edit_dns_zone() {
    print_header "Edit DNS Zone"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone to edit:"
    for i in "${!zones[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${zones[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#zones[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#zones[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local zone="${zones[$((selection-1))]}"
    local zone_file="$BIND_ZONES_DIR/db.$zone"
    
    backup_file "$zone_file"
    ${EDITOR:-nano} "$zone_file"
    
    if named-checkzone "$zone" "$zone_file" >/dev/null 2>&1; then
        print_success "Zone file syntax is valid"
        restart_service "bind9"
        print_success "Zone updated and BIND reloaded"
    else
        print_error "Zone file syntax error"
    fi
    
    pause_menu
}

delete_dns_zone() {
    print_header "Delete DNS Zone"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone to delete:"
    for i in "${!zones[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${zones[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#zones[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#zones[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local zone="${zones[$((selection-1))]}"
    
    if prompt_yes_no "Delete DNS zone for $zone?"; then
        rm -f "$BIND_ZONES_DIR/db.$zone"
        sed -i "/^zone \"$zone\"/,/^}/d" "/etc/bind/named.conf.local"
        restart_service "bind9"
        print_success "DNS zone deleted for $zone"
    fi
    
    pause_menu
}

check_dns_status() {
    print_header "DNS Status"
    
    if service_running "bind9"; then
        echo -e "${GREEN}✓ BIND9 Service${NC}: Running"
    else
        echo -e "${RED}✗ BIND9 Service${NC}: Stopped"
    fi
    
    echo ""
    echo -e "${BOLD}Configured Zones:${NC}"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        echo "  No zones configured"
    else
        for zone in "${zones[@]}"; do
            local zone_file="$BIND_ZONES_DIR/db.$zone"
            if named-checkzone "$zone" "$zone_file" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $zone"
            else
                echo -e "  ${RED}✗${NC} $zone (Invalid syntax)"
            fi
        done
    fi
    
    echo ""
    pause_menu
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

list_mail_accounts() {
    print_header "Mail Accounts"
    
    if [ ! -d "$MAIL_USERS_DIR" ]; then
        print_info "No mail accounts configured"
        pause_menu
        return
    fi
    
    local accounts=$(ls -d "$MAIL_USERS_DIR"/*/ 2>/dev/null | xargs -n 1 basename)
    
    if [ -z "$accounts" ]; then
        print_info "No mail accounts configured"
        pause_menu
        return
    fi
    
    echo -e "${BOLD}Configured Mail Accounts:${NC}"
    echo ""
    
    echo "$accounts" | while read account; do
        echo -e "  ${CYAN}•${NC} $account"
        
        local mailbox="$MAIL_USERS_DIR/$account/Maildir"
        if [ -d "$mailbox" ]; then
            local size=$(du -sh "$mailbox" 2>/dev/null | cut -f1)
            echo "      Size: $size"
        fi
        
        echo ""
    done
    
    pause_menu
}

edit_mail_account() {
    print_header "Edit Mail Account"
    
    local accounts=$(ls -d "$MAIL_USERS_DIR"/*/ 2>/dev/null | xargs -n 1 basename)
    
    if [ -z "$accounts" ]; then
        print_info "No mail accounts to edit"
        pause_menu
        return
    fi
    
    local -a account_list=($accounts)
    
    echo "Select account to edit:"
    echo ""
    
    for i in "${!account_list[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${account_list[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#account_list[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#account_list[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local email="${account_list[$((selection-1))]}"
    
    print_header "Edit Account: $email"
    
    echo -e "  ${CYAN}1)${NC} View account info"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1) show_mail_account_info "$email" ;;
        0) return ;;
    esac
}

show_mail_account_info() {
    local email="$1"
    
    print_header "Mail Account Information"
    
    echo -e "${BOLD}Email:${NC}"
    echo "  $email"
    echo ""
    
    echo -e "${BOLD}Mailbox Path:${NC}"
    echo "  $MAIL_USERS_DIR/$email/Maildir"
    echo ""
    
    echo -e "${BOLD}Mailbox Size:${NC}"
    local size=$(du -sh "$MAIL_USERS_DIR/$email/Maildir" 2>/dev/null | cut -f1)
    echo "  $size"
    echo ""
    
    pause_menu
}

delete_mail_account() {
    print_header "Delete Mail Account"
    
    local accounts=$(ls -d "$MAIL_USERS_DIR"/*/ 2>/dev/null | xargs -n 1 basename)
    
    if [ -z "$accounts" ]; then
        print_info "No mail accounts to delete"
        pause_menu
        return
    fi
    
    local -a account_list=($accounts)
    
    echo "Select account to delete:"
    for i in "${!account_list[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${account_list[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#account_list[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#account_list[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local email="${account_list[$((selection-1))]}"
    
    print_warning "This will permanently delete the mail account: $email"
    if prompt_yes_no "Continue?"; then
        rm -rf "$MAIL_USERS_DIR/$email"
        print_success "Mail account deleted: $email"
    fi
    
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
        
        if prompt_yes_no "Create database user for this database?"; then
            local username=$(get_input "Database username" "${db_name}_user")
            local password
            read -sp "Database password: " password
            echo ""
            
            if $db_cmd -u root -proot -e "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';" 2>/dev/null; then
                $db_cmd -u root -proot -e "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$username'@'localhost';" 2>/dev/null
                $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
                print_success "Database user created: $username"
            fi
        fi
    else
        print_error "Failed to create database"
    fi
    
    pause_menu
}

add_database_user() {
    print_header "Add Database User"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local username=$(get_input "Username")
    local password
    read -sp "Password: " password
    echo ""
    
    local db_cmd=$(get_db_command)
    
    if $db_cmd -u root -proot -e "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';" 2>/dev/null; then
        if prompt_yes_no "Grant all privileges?"; then
            $db_cmd -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO '$username'@'localhost';" 2>/dev/null
        fi
        $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
        print_success "Database user created: $username"
    else
        print_error "Failed to create user"
    fi
    
    pause_menu
}

edit_database() {
    print_header "Edit Database"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    local -a databases
    while IFS= read -r db; do
        if [[ ! "$db" =~ ^(information_schema|mysql|performance_schema|sys)$ ]]; then
            databases+=("$db")
        fi
    done < <($db_cmd -u root -proot -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    
    if [ ${#databases[@]} -eq 0 ]; then
        print_info "No user databases found"
        pause_menu
        return
    fi
    
    echo "Select database:"
    for i in "${!databases[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${databases[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#databases[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#databases[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local database="${databases[$((selection-1))]}"
    show_database_info "$database"
}

show_database_info() {
    local database="$1"
    local db_cmd=$(get_db_command)
    
    print_header "Database Information: $database"
    
    echo -e "${BOLD}Database Name:${NC}"
    echo "  $database"
    echo ""
    
    echo -e "${BOLD}Size:${NC}"
    local size=$($db_cmd -u root -proot -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '$database';" 2>/dev/null | tail -1)
    echo "  ${size}MB"
    echo ""
    
    echo -e "${BOLD}Tables:${NC}"
    $db_cmd -u root -proot -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE table_schema = '$database';" 2>/dev/null | tail -n +2 | while read table; do
        echo "  • $table"
    done
    echo ""
    
    pause_menu
}

delete_database() {
    print_header "Delete Database"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    local -a databases
    while IFS= read -r db; do
        if [[ ! "$db" =~ ^(information_schema|mysql|performance_schema|sys)$ ]]; then
            databases+=("$db")
        fi
    done < <($db_cmd -u root -proot -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
    
    if [ ${#databases[@]} -eq 0 ]; then
        print_info "No user databases found"
        pause_menu
        return
    fi
    
    echo "Select database to delete:"
    for i in "${!databases[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${databases[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#databases[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#databases[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local database="${databases[$((selection-1))]}"
    
    print_warning "This will permanently delete: $database"
    
    if prompt_yes_no "Delete database $database?"; then
        if $db_cmd -u root -proot -e "DROP DATABASE \`$database\`;" 2>/dev/null; then
            print_success "Database deleted: $database"
        else
            print_error "Failed to delete database"
        fi
    fi
    
    pause_menu
}

edit_database_user() {
    print_header "Edit Database User"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    local -a users
    while IFS= read -r user; do
        users+=("$user")
    done < <($db_cmd -u root -proot -e "SELECT CONCAT(user,'@',host) FROM mysql.user WHERE user NOT IN ('root', 'mysql.sys', 'mysql.session');" 2>/dev/null | tail -n +2)
    
    if [ ${#users[@]} -eq 0 ]; then
        print_info "No user accounts found"
        pause_menu
        return
    fi
    
    echo "Select user:"
    for i in "${!users[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${users[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#users[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#users[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local user="${users[$((selection-1))]}"
    local username="${user%%@*}"
    local host="${user##*@}"
    
    local new_password
    read -sp "New password: " new_password
    echo ""
    
    if $db_cmd -u root -proot -e "ALTER USER '$username'@'$host' IDENTIFIED BY '$new_password';" 2>/dev/null; then
        $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
        print_success "Password changed for $user"
    else
        print_error "Failed to change password"
    fi
    
    pause_menu
}

delete_database_user() {
    print_header "Delete Database User"
    
    if ! check_db_connection; then
        print_error "Cannot connect to database server"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    local -a users
    while IFS= read -r user; do
        users+=("$user")
    done < <($db_cmd -u root -proot -e "SELECT CONCAT(user,'@',host) FROM mysql.user WHERE user NOT IN ('root', 'mysql.sys', 'mysql.session');" 2>/dev/null | tail -n +2)
    
    if [ ${#users[@]} -eq 0 ]; then
        print_info "No user accounts found"
        pause_menu
        return
    fi
    
    echo "Select user to delete:"
    for i in "${!users[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${users[$i]}"
    done
    
    echo ""
    read -p "Enter selection [1-${#users[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#users[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local user="${users[$((selection-1))]}"
    local username="${user%%@*}"
    local host="${user##*@}"
    
    if prompt_yes_no "Delete user $user?"; then
        if $db_cmd -u root -proot -e "DROP USER '$username'@'$host';" 2>/dev/null; then
            $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
            print_success "User deleted: $user"
        else
            print_error "Failed to delete user"
        fi
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

backup_full_system() {
    print_header "Full System Backup"
    
    print_warning "This will create a complete backup of all websites and databases"
    if ! prompt_yes_no "Continue?"; then
        return
    fi
    
    local backup_dir="$BACKUP_ROOT/full"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/full_system_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    print_info "Creating full system backup (this may take significant time)..."
    
    print_info "Backing up websites..."
    tar -czf "$backup_file.websites" /root/websites 2>/dev/null || print_warning "Website backup failed"
    
    print_info "Backing up databases..."
    local db_cmd=$(get_db_command)
    $db_cmd -u root -proot --all-databases 2>/dev/null | gzip > "$backup_dir/databases_$(date +%Y%m%d_%H%M%S).sql.gz" || print_warning "Database backup failed"
    
    local size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
    print_success "Full system backup completed in $backup_dir ($size)"
    
    pause_menu
}

restore_backup() {
    print_header "Restore Backup"
    
    local -a backup_files
    while IFS= read -r file; do
        backup_files+=("$file")
    done < <(find "$BACKUP_ROOT" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" \) 2>/dev/null | sort -r)
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        print_info "No backups found"
        pause_menu
        return
    fi
    
    echo "Available backups:"
    echo ""
    
    for i in "${!backup_files[@]}"; do
        local size=$(du -h "${backup_files[$i]}" | cut -f1)
        local name=$(basename "${backup_files[$i]}")
        echo -e "  ${CYAN}$((i+1)))${NC} $name ($size)"
    done
    
    echo ""
    read -p "Select backup to restore [1-${#backup_files[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#backup_files[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local backup_file="${backup_files[$((selection-1))]}"
    local filename=$(basename "$backup_file")
    
    print_warning "This will restore from backup: $filename"
    if ! prompt_yes_no "Continue?"; then
        return
    fi
    
    print_info "Restoring backup (this may take a while)..."
    
    case "$filename" in
        *.tar.gz)
            if tar -xzf "$backup_file" -C / 2>/dev/null; then
                print_success "Backup restored successfully"
            else
                print_error "Failed to restore backup"
            fi
            ;;
        *.sql.gz)
            local temp_sql="/tmp/restore_db.sql"
            gunzip -c "$backup_file" > "$temp_sql"
            
            local db_cmd=$(get_db_command)
            if $db_cmd -u root -proot < "$temp_sql" 2>/dev/null; then
                print_success "Database backup restored successfully"
                rm -f "$temp_sql"
            else
                print_error "Failed to restore database backup"
            fi
            ;;
    esac
    
    pause_menu
}

cleanup_old_backups() {
    print_header "Cleanup Old Backups"
    
    echo "Delete backups older than:"
    echo -e "  ${CYAN}1)${NC} 7 days"
    echo -e "  ${CYAN}2)${NC} 14 days"
    echo -e "  ${CYAN}3)${NC} 30 days"
    echo ""
    
    read -p "Select option [1-3]: " choice
    
    local days
    case "$choice" in
        1) days=7 ;;
        2) days=14 ;;
        3) days=30 ;;
        *)
            print_error "Invalid choice"
            pause_menu
            return
            ;;
    esac
    
    print_info "Deleting backups older than $days days..."
    find "$BACKUP_ROOT" -type f -mtime +$days -delete
    print_success "Old backups cleaned up"
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

add_website_backup_cron() {
    local hour=$(get_input "Hour for website backup (0-23)" "2")
    local minute=$(get_input "Minute (0-59)" "0")
    
    local command="$minute $hour * * * tar -czf /root/backups/websites/backup_\$(date +\%Y\%m\%d).tar.gz /root/websites"
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    print_success "Website backup scheduled for $hour:$minute"
}

add_database_backup_cron() {
    local hour=$(get_input "Hour for database backup (0-23)" "3")
    local minute=$(get_input "Minute (0-59)" "0")
    
    local db_cmd=$(get_db_command)
    local command="$minute $hour * * * $db_cmd -u root -proot --all-databases 2>/dev/null | gzip > /root/backups/databases/backup_\$(date +\%Y\%m\%d).sql.gz"
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    print_success "Database backup scheduled for $hour:$minute"
}

add_ssl_renewal_cron() {
    local command="0 3 * * * certbot renew --non-interactive --quiet"
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    print_success "SSL renewal scheduled for 3:00 AM daily"
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
}

edit_cron_job() {
    print_header "Edit Cron Jobs"
    
    local user=$(get_input "Edit crontab for user" "root")
    crontab -u "$user" -e
}

delete_cron_job() {
    print_header "Delete Cron Job"
    
    local user=$(get_input "User to edit" "root")
    
    local -a jobs
    while IFS= read -r line; do
        jobs+=("$line")
    done < <(crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$")
    
    if [ ${#jobs[@]} -eq 0 ]; then
        print_info "No cron jobs found for $user"
        pause_menu
        return
    fi
    
    echo "Select cron job to delete:"
    for i in "${!jobs[@]}"; do
        echo -e "  ${CYAN}$((i+1)))${NC} ${jobs[$i]:0:60}..."
    done
    
    echo ""
    read -p "Enter selection [1-${#jobs[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#jobs[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local job_to_delete="${jobs[$((selection-1))]}"
    
    if prompt_yes_no "Delete this cron job?"; then
        (crontab -u "$user" -l 2>/dev/null | grep -v "$job_to_delete") | crontab -u "$user" - 2>/dev/null
        print_success "Cron job deleted"
    fi
    
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

manage_services() {
    print_header "Service Management"
    
    local -a installed_services
    
    local services=("nginx" "apache2" "mariadb" "mysql" "bind9" "postfix" "dovecot")
    
    for service in "${services[@]}"; do
        if package_installed "$service"; then
            installed_services+=("$service")
        fi
    done
    
    if [ ${#installed_services[@]} -eq 0 ]; then
        print_info "No services installed"
        pause_menu
        return
    fi
    
    echo "Select service to manage:"
    echo ""
    
    for i in "${!installed_services[@]}"; do
        local service="${installed_services[$i]}"
        if service_running "$service"; then
            echo -e "  ${CYAN}$((i+1)))${NC} $service ${GREEN}(Running)${NC}"
        else
            echo -e "  ${CYAN}$((i+1)))${NC} $service ${RED}(Stopped)${NC}"
        fi
    done
    
    echo ""
    read -p "Enter selection [1-${#installed_services[@]}]: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ $selection -lt 1 ] || [ $selection -gt ${#installed_services[@]} ]; then
        print_error "Invalid selection"
        pause_menu
        return
    fi
    
    local service="${installed_services[$((selection-1))]}"
    
    print_header "Manage Service: $service"
    
    echo -e "  ${CYAN}1)${NC} Start"
    echo -e "  ${CYAN}2)${NC} Stop"
    echo -e "  ${CYAN}3)${NC} Restart"
    echo -e "  ${CYAN}4)${NC} Enable at startup"
    echo -e "  ${CYAN}5)${NC} Disable at startup"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select action: " action
    
    case "$action" in
        1) start_service "$service" ;;
        2) stop_service "$service" ;;
        3) restart_service "$service" ;;
        4) enable_service "$service" ;;
        5) disable_service "$service" ;;
        0) return ;;
    esac
    
    pause_menu
}

show_system_info() {
    print_header "System Information"
    
    echo -e "${BOLD}Hostname:${NC}"
    echo "  $(hostname)"
    echo ""
    
    echo -e "${BOLD}Operating System:${NC}"
    source /etc/os-release 2>/dev/null
    echo "  $PRETTY_NAME"
    echo ""
    
    echo -e "${BOLD}Kernel:${NC}"
    echo "  $(uname -r)"
    echo ""
    
    echo -e "${BOLD}CPU:${NC}"
    echo "  $(grep -c ^processor /proc/cpuinfo) cores"
    echo ""
    
    echo -e "${BOLD}Memory:${NC}"
    local total_mem=$(free -h | grep Mem | awk '{print $2}')
    local used_mem=$(free -h | grep Mem | awk '{print $3}')
    echo "  Used: $used_mem / Total: $total_mem"
    echo ""
    
    echo -e "${BOLD}Disk Usage:${NC}"
    df -h / | tail -1 | awk '{printf "  Used: %s / Total: %s (%.0f%%)\n", $3, $2, $5}'
    echo ""
    
    echo -e "${BOLD}Uptime:${NC}"
    echo "  $(uptime -p)"
    echo ""
    
    pause_menu
}

change_db_password() {
    print_header "Change Database Root Password"
    
    local db_type=$(get_config "DATABASE" "mariadb-server")
    
    if ! service_running "$db_type"; then
        print_error "Database service is not running"
        pause_menu
        return
    fi
    
    print_warning "This will change the root password for $db_type"
    
    local new_password
    read -sp "New root password: " new_password
    echo ""
    read -sp "Confirm password: " confirm_password
    echo ""
    
    if [ "$new_password" != "$confirm_password" ]; then
        print_error "Passwords do not match"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    
    if $db_cmd -u root -proot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$new_password';" 2>/dev/null; then
        print_success "Database root password changed"
    else
        print_error "Failed to change password"
    fi
    
    pause_menu
}

configure_firewall() {
    print_header "Firewall Configuration"
    
    if ! command_exists "ufw"; then
        print_error "UFW firewall not installed"
        if prompt_yes_no "Install UFW?"; then
            apt-get install -y ufw >/dev/null 2>&1
            ufw --force enable >/dev/null 2>&1
            print_success "UFW installed and enabled"
        fi
        pause_menu
        return
    fi
    
    echo -e "  ${CYAN}1)${NC} View firewall status"
    echo -e "  ${CYAN}2)${NC} Enable firewall"
    echo -e "  ${CYAN}3)${NC} Disable firewall"
    echo -e "  ${CYAN}4)${NC} Allow port"
    echo -e "  ${CYAN}5)${NC} Deny port"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            print_header "Firewall Status"
            ufw status
            ;;
        2)
            ufw --force enable
            print_success "Firewall enabled"
            ;;
        3)
            ufw disable
            print_success "Firewall disabled"
            ;;
        4)
            local port=$(get_input "Enter port number")
            ufw allow "$port"
            print_success "Port $port allowed"
            ;;
        5)
            local port=$(get_input "Enter port number")
            ufw deny "$port"
            print_success "Port $port denied"
            ;;
        0)
            return
            ;;
    esac
    
    pause_menu
}

view_logs() {
    print_header "View Logs"
    
    echo "Select log to view:"
    echo ""
    echo -e "  ${CYAN}1)${NC} EasyPanel logs"
    echo -e "  ${CYAN}2)${NC} Web server error logs"
    echo -e "  ${CYAN}3)${NC} System logs"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            ${EDITOR:-less} /var/log/easypanel.log
            ;;
        2)
            local web_server=$(get_config "WEB_SERVER")
            case "$web_server" in
                apache2)
                    ${EDITOR:-less} /var/log/apache2/error.log
                    ;;
                nginx)
                    ${EDITOR:-less} /var/log/nginx/error.log
                    ;;
            esac
            ;;
        3)
            ${EDITOR:-less} /var/log/syslog
            ;;
        0)
            return
            ;;
    esac
}

security_settings() {
    print_header "Security Settings"
    
    echo -e "  ${CYAN}1)${NC} Install fail2ban"
    echo -e "  ${CYAN}2)${NC} System updates"
    echo -e "  ${CYAN}3)${NC} View installed packages count"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            if command_exists "fail2ban-client"; then
                print_info "fail2ban is already installed"
            else
                print_info "Installing fail2ban..."
                apt-get install -y fail2ban >/dev/null 2>&1
                enable_service "fail2ban"
                print_success "fail2ban installed"
            fi
            ;;
        2)
            print_info "Checking for updates..."
            apt-get update >/dev/null 2>&1
            apt-get upgrade -y 2>&1 | tail -5
            print_success "System updated"
            ;;
        3)
            print_header "Installed Packages"
            dpkg -l | grep "^ii" | wc -l
            echo " packages installed"
            ;;
        0)
            return
            ;;
    esac
    
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
        echo -e "  ${CYAN}3)${NC} Edit Domain"
        echo -e "  ${CYAN}4)${NC} Delete Domain"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-4]: " choice
        
        case "$choice" in
            1) list_domains_display ;;
            2) add_domain ;;
            3) edit_domain ;;
            4) delete_domain ;;
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
        
        echo -e "  ${CYAN}1)${NC} List DNS Records"
        echo -e "  ${CYAN}2)${NC} Create DNS Zone"
        echo -e "  ${CYAN}3)${NC} Add DNS Record"
        echo -e "  ${CYAN}4)${NC} Edit DNS Zone"
        echo -e "  ${CYAN}5)${NC} Delete DNS Zone"
        echo -e "  ${CYAN}6)${NC} DNS Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-6]: " choice
        
        case "$choice" in
            1) list_dns_records ;;
            2) create_dns_zone ;;
            3) add_dns_record ;;
            4) edit_dns_zone ;;
            5) delete_dns_zone ;;
            6) check_dns_status ;;
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
        
        echo -e "  ${CYAN}1)${NC} List Mail Accounts"
        echo -e "  ${CYAN}2)${NC} Add Mail Account"
        echo -e "  ${CYAN}3)${NC} Edit Mail Account"
        echo -e "  ${CYAN}4)${NC} Show Mail Account Info"
        echo -e "  ${CYAN}5)${NC} Delete Mail Account"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-5]: " choice
        
        case "$choice" in
            1) list_mail_accounts ;;
            2) add_mail_account ;;
            3) edit_mail_account ;;
            4) show_mail_account_info ;;
            5) delete_mail_account ;;
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
        echo -e "  ${CYAN}3)${NC} Edit Database"
        echo -e "  ${CYAN}4)${NC} Show Database Info"
        echo -e "  ${CYAN}5)${NC} Delete Database"
        echo -e "  ${CYAN}6)${NC} Database Users"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-6]: " choice
        
        case "$choice" in
            1) list_databases ;;
            2) create_database ;;
            3) edit_database ;;
            4) show_database_info ;;
            5) delete_database ;;
            6)
                while true; do
                    print_header "Database Users"
                    echo -e "  ${CYAN}1)${NC} Add Database User"
                    echo -e "  ${CYAN}2)${NC} Edit Database User"
                    echo -e "  ${CYAN}3)${NC} Delete Database User"
                    echo -e "  ${CYAN}0)${NC} Back"
                    print_separator
                    read -p "Select option [0-3]: " user_choice
                    case "$user_choice" in
                        1) add_database_user ;;
                        2) edit_database_user ;;
                        3) delete_database_user ;;
                        0) break ;;
                        *) print_error "Invalid option"; pause_menu ;;
                    esac
                done
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
        echo -e "  ${CYAN}2)${NC} Add Website Backup Cron"
        echo -e "  ${CYAN}3)${NC} Add Database Backup Cron"
        echo -e "  ${CYAN}4)${NC} Add SSL Renewal Cron"
        echo -e "  ${CYAN}5)${NC} Add Custom Cron Job"
        echo -e "  ${CYAN}6)${NC} Edit Cron Job"
        echo -e "  ${CYAN}7)${NC} Delete Cron Job"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-7]: " choice
        
        case "$choice" in
            1) list_cron_jobs ;;
            2) add_website_backup_cron ;;
            3) add_database_backup_cron ;;
            4) add_ssl_renewal_cron ;;
            5) add_custom_cron ;;
            6) edit_cron_job ;;
            7) delete_cron_job ;;
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
        echo -e "  ${CYAN}3)${NC} Backup Full System"
        echo -e "  ${CYAN}4)${NC} List Backups"
        echo -e "  ${CYAN}5)${NC} Restore Backup"
        echo -e "  ${CYAN}6)${NC} Cleanup Old Backups"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-6]: " choice
        
        case "$choice" in
            1) backup_websites ;;
            2) backup_databases ;;
            3) backup_full_system ;;
            4) list_backups ;;
            5) restore_backup ;;
            6) cleanup_old_backups ;;
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
        echo -e "  ${CYAN}2)${NC} System Info"
        echo -e "  ${CYAN}3)${NC} Manage Services"
        echo -e "  ${CYAN}4)${NC} View Logs"
        echo -e "  ${CYAN}5)${NC} Security Settings"
        echo -e "  ${CYAN}6)${NC} Configure Firewall"
        echo -e "  ${CYAN}7)${NC} Change Database Password"
        echo -e "  ${CYAN}8)${NC} System Status"
        echo -e "  ${CYAN}9)${NC} About EasyPanel"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-9]: " choice
        
        case "$choice" in
            1) show_configuration ;;
            2) show_system_info ;;
            3) manage_services ;;
            4) view_logs ;;
            5) security_settings ;;
            6) configure_firewall ;;
            7) change_db_password ;;
            8) show_system_status ;;
            9) show_about ;;
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
