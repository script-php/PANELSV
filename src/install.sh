#!/bin/bash

################################################################################
# EasyPanel - Installation Script
# Handles installation and configuration of all required services
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

################################################################################
# Installation Functions
################################################################################

# Check system requirements
check_system_requirements() {
    print_header "Checking System Requirements"
    
    # Check if running on Debian/Ubuntu
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
    
    # Update package list
    print_info "Updating package lists..."
    apt-get update >/dev/null 2>&1 || print_warning "Failed to update package lists"
    
    pause_menu
}

# Detect installed services
detect_installed_services() {
    print_header "Detecting Installed Services"
    
    local installed=()
    
    if package_installed "apache2"; then
        installed+=("Apache2")
    fi
    
    if package_installed "nginx"; then
        installed+=("Nginx")
    fi
    
    if package_installed "mysql-server"; then
        installed+=("MySQL Server")
    fi
    
    if package_installed "mariadb-server"; then
        installed+=("MariaDB Server")
    fi
    
    if package_installed "bind9"; then
        installed+=("BIND DNS")
    fi
    
    if package_installed "postfix"; then
        installed+=("Postfix")
    fi
    
    if [ ${#installed[@]} -eq 0 ]; then
        print_info "No major services detected"
        return 0
    fi
    
    echo "The following services are already installed:"
    for service in "${installed[@]}"; do
        echo "  • $service"
    done
    
    echo ""
    if prompt_yes_no "Would you like to remove and reinstall these services?"; then
        print_warning "This will remove all installed services and their configurations"
        if prompt_yes_no "Are you absolutely sure?"; then
            remove_existing_services
        fi
    fi
    
    pause_menu
}

# Remove existing services
remove_existing_services() {
    print_header "Removing Existing Services"
    
    local packages_to_remove=(
        "apache2"
        "apache2-*"
        "nginx"
        "nginx-*"
        "php-fpm"
        "php*"
        "mysql-server"
        "mysql-client"
        "mariadb-server"
        "mariadb-client"
        "bind9"
        "bind9-utils"
        "postfix"
        "dovecot-core"
        "dovecot-imapd"
        "dovecot-pop3d"
        "roundcube"
    )
    
    print_info "This may take several minutes..."
    
    for package in "${packages_to_remove[@]}"; do
        apt-get purge -y "$package" >/dev/null 2>&1
    done
    
    apt-get autoremove -y >/dev/null 2>&1
    apt-get autoclean -y >/dev/null 2>&1
    
    print_success "Removed existing services"
}

# Prompt for web server choice
select_web_server() {
    print_header "Select Web Server"
    
    echo "Which web server would you like to install?"
    echo ""
    echo -e "  ${CYAN}1)${NC} Apache2"
    echo -e "  ${CYAN}2)${NC} Nginx (Recommended)"
    echo ""
    
    read -p "Select [1-2]: " choice
    
    case "$choice" in
        1)
            WEB_SERVER="apache2"
            print_info "Selected: Apache2"
            ;;
        2)
            WEB_SERVER="nginx"
            print_info "Selected: Nginx"
            ;;
        *)
            print_error "Invalid choice"
            select_web_server
            return
            ;;
    esac
    
    pause_menu
}

# Prompt for database choice
select_database() {
    print_header "Select Database Server"
    
    echo "Which database server would you like to install?"
    echo ""
    echo -e "  ${CYAN}1)${NC} MySQL"
    echo -e "  ${CYAN}2)${NC} MariaDB (Recommended)"
    echo ""
    
    read -p "Select [1-2]: " choice
    
    case "$choice" in
        1)
            DATABASE="mysql-server"
            print_info "Selected: MySQL"
            ;;
        2)
            DATABASE="mariadb-server"
            print_info "Selected: MariaDB"
            ;;
        *)
            print_error "Invalid choice"
            select_database
            return
            ;;
    esac
    
    pause_menu
}

# Install web server
install_web_server() {
    print_header "Installing Web Server"
    
    case "$WEB_SERVER" in
        apache2)
            install_apache2
            ;;
        nginx)
            install_nginx
            ;;
    esac
}

# Install Apache2
install_apache2() {
    print_info "Installing Apache2..."
    
    # Install Apache2
    apt-get install -y apache2 apache2-utils apache2-dev >/dev/null 2>&1 || {
        print_error "Failed to install Apache2"
        return 1
    }
    
    # Enable required modules
    a2enmod rewrite >/dev/null 2>&1
    a2enmod ssl >/dev/null 2>&1
    a2enmod proxy >/dev/null 2>&1
    a2enmod proxy_fcgi >/dev/null 2>&1
    a2enmod headers >/dev/null 2>&1
    a2enmod http2 >/dev/null 2>&1
    a2enmod setenvif >/dev/null 2>&1
    
    # Create default configuration directory
    mkdir -p /etc/apache2/sites-available/easypanel
    
    # Enable Apache2 service
    enable_service "apache2"
    restart_service "apache2"
    
    print_success "Apache2 installed and configured"
}

# Install Nginx
install_nginx() {
    print_info "Installing Nginx..."
    
    # Install Nginx
    apt-get install -y nginx nginx-common >/dev/null 2>&1 || {
        print_error "Failed to install Nginx"
        return 1
    }
    
    # Create configuration directories
    mkdir -p /etc/nginx/sites-available/easypanel
    mkdir -p /etc/nginx/sites-enabled/easypanel
    
    # Enable Nginx service
    enable_service "nginx"
    restart_service "nginx"
    
    print_success "Nginx installed and configured"
}

# Install PHP-FPM
install_php_fpm() {
    print_header "Installing PHP-FPM"
    
    echo "Which PHP versions would you like to install?"
    echo ""
    echo -e "  ${CYAN}1)${NC} Latest (8.3/8.4)"
    echo -e "  ${CYAN}2)${NC} Multiple versions (5.6, 7.0, 7.1, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4)"
    echo -e "  ${CYAN}3)${NC} Skip PHP installation"
    echo ""
    
    read -p "Select [1-3]: " choice
    
    case "$choice" in
        1)
            install_php_version "8.4"
            ;;
        2)
            print_info "This will install multiple PHP versions and may take significant time..."
            if prompt_yes_no "Continue?"; then
                # Add PHP repository
                apt-get install -y software-properties-common >/dev/null 2>&1
                add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1
                apt-get update >/dev/null 2>&1
                
                local versions=("5.6" "7.0" "7.1" "7.4" "8.0" "8.1" "8.2" "8.3" "8.4")
                for version in "${versions[@]}"; do
                    install_php_version "$version" &
                done
                wait
            fi
            ;;
        3)
            print_info "Skipping PHP installation"
            ;;
        *)
            print_error "Invalid choice"
            install_php_fpm
            return
            ;;
    esac
    
    pause_menu
}

# Install specific PHP version
install_php_version() {
    local version="$1"
    
    print_info "Installing PHP $version..."
    
    local packages=(
        "php$version-fpm"
        "php$version-cli"
        "php$version-dev"
        "php$version-mbstring"
        "php$version-xml"
        "php$version-mysql"
        "php$version-pgsql"
        "php$version-curl"
        "php$version-gd"
        "php$version-imap"
        "php$version-intl"
        "php$version-json"
        "php$version-ldap"
        "php$version-pear"
        "php$version-zip"
        "php$version-bz2"
    )
    
    apt-get install -y "${packages[@]}" >/dev/null 2>&1
    
    if command_exists "php$version"; then
        enable_service "php$version-fpm"
        restart_service "php$version-fpm"
        print_success "PHP $version installed"
    else
        print_warning "PHP $version installation may have failed"
    fi
}

# Install Database Server
install_database() {
    print_header "Installing Database Server"
    
    case "$DATABASE" in
        mysql-server)
            install_mysql
            ;;
        mariadb-server)
            install_mariadb
            ;;
    esac
}

# Install MySQL
install_mysql() {
    print_info "Installing MySQL Server..."
    
    # Set root password through debconf to avoid interactive prompt
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

# Install MariaDB
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

# Install DNS Server (BIND)
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
    
    # Create directory for zone files
    mkdir -p /etc/bind/easypanel
    chown -R bind:bind /etc/bind/easypanel
    
    enable_service "bind9"
    restart_service "bind9"
    
    print_success "BIND9 DNS Server installed"
}

# Install Mail Server
install_mail_server() {
    print_header "Installing Mail Server"
    
    if ! prompt_yes_no "Install Mail Server?"; then
        print_info "Skipping Mail Server installation"
        return
    fi
    
    # Install Postfix
    print_info "Installing Postfix..."
    echo "postfix postfix/mailname string localhost" | debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
    
    apt-get install -y postfix >/dev/null 2>&1 || {
        print_error "Failed to install Postfix"
        return 1
    }
    
    # Install Dovecot
    print_info "Installing Dovecot..."
    apt-get install -y dovecot-core dovecot-imapd dovecot-pop3d sieve-tools >/dev/null 2>&1 || {
        print_error "Failed to install Dovecot"
        return 1
    }
    
    # Install ClamAV
    print_info "Installing ClamAV..."
    apt-get install -y clamav clamav-daemon >/dev/null 2>&1 || {
        print_warning "ClamAV installation may have failed"
    }
    
    # Install SpamAssassin
    print_info "Installing SpamAssassin..."
    apt-get install -y spamassassin spamc >/dev/null 2>&1 || {
        print_warning "SpamAssassin installation may have failed"
    }
    
    # Install Roundcube (optional)
    if prompt_yes_no "Install Roundcube Webmail?"; then
        print_info "Installing Roundcube..."
        apt-get install -y roundcube roundcube-plugins >/dev/null 2>&1 || {
            print_warning "Roundcube installation may have failed"
        fi
        print_success "Roundcube installed"
    fi
    
    enable_service "postfix"
    enable_service "dovecot"
    restart_service "postfix"
    restart_service "dovecot"
    
    print_success "Mail Server installed and configured"
}

# Install SSL/Let's Encrypt
install_certbot() {
    print_header "Installing Let's Encrypt Support"
    
    print_info "Installing Certbot..."
    
    apt-get install -y certbot python3-certbot-${WEB_SERVER} >/dev/null 2>&1 || {
        print_error "Failed to install Certbot"
        return 1
    }
    
    # Create renewal hook directory
    mkdir -p /etc/letsencrypt/renewal-hooks/post
    
    print_success "Let's Encrypt support installed"
}

# Install Firewall
install_firewall() {
    print_header "Installing Firewall"
    
    if ! prompt_yes_no "Install Firewall (fail2ban + iptables)?"; then
        print_info "Skipping Firewall installation"
        return
    fi
    
    print_info "Installing fail2ban..."
    apt-get install -y fail2ban ipset >/dev/null 2>&1 || {
        print_error "Failed to install fail2ban"
        return 1
    }
    
    # Copy default jail configuration
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2>/dev/null
    
    enable_service "fail2ban"
    restart_service "fail2ban"
    
    print_success "Firewall components installed"
}

# Create required directories
create_required_directories() {
    print_header "Creating Required Directories"
    
    create_directory "/root/websites" "root" "755"
    create_directory "/var/log/easypanel" "root" "755"
    create_directory "/etc/easypanel" "root" "755"
    
    print_success "Directory structure created"
}

# Summary and save configuration
save_installation_config() {
    print_header "Installation Summary"
    
    echo -e "${BOLD}Selected Configuration:${NC}"
    echo "  Web Server: $WEB_SERVER"
    echo "  Database: $DATABASE"
    echo ""
    
    # Save configuration
    set_config "WEB_SERVER" "$WEB_SERVER"
    set_config "DATABASE" "$DATABASE"
    set_config "PANEL_INSTALLED_DATE" "$(date)"
    
    print_success "Configuration saved to /etc/easypanel/config"
    print_success "Installation complete!"
    
    echo ""
    print_info "Next steps:"
    echo "  1. Use 'easypanel domains' to add your first domain"
    echo "  2. Use 'easypanel dns' to configure DNS records"
    echo "  3. Use 'easypanel mail' to set up mail accounts"
    echo "  4. Use 'easypanel databases' to create databases"
    echo ""
    
    pause_menu
}

################################################################################
# Main Installation Menu
################################################################################

install_menu() {
    while true; do
        print_header "Installation Menu"
        
        echo -e "  ${CYAN}1)${NC} Run Full Installation"
        echo -e "  ${CYAN}2)${NC} Check System Requirements"
        echo -e "  ${CYAN}3)${NC} Detect Installed Services"
        echo -e "  ${CYAN}4)${NC} Install Web Server Only"
        echo -e "  ${CYAN}5)${NC} Install Database Only"
        echo -e "  ${CYAN}6)${NC} Install PHP-FPM Only"
        echo -e "  ${CYAN}7)${NC} Install Mail Server Only"
        echo -e "  ${CYAN}8)${NC} Install DNS Server Only"
        echo -e "  ${CYAN}9)${NC} Install Firewall Only"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-9]: " choice
        
        case "$choice" in
            1) run_installation ;;
            2) check_system_requirements ;;
            3) detect_installed_services ;;
            4) select_web_server; install_web_server ;;
            5) select_database; install_database ;;
            6) install_php_fpm ;;
            7) install_mail_server ;;
            8) install_dns_server ;;
            9) install_firewall ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}

# Run full installation
run_installation() {
    print_header "EasyPanel - Full Installation Wizard"
    
    print_warning "This installation will configure your system as a web server."
    if ! prompt_yes_no "Continue with installation?"; then
        print_info "Installation cancelled"
        return
    fi
    
    check_system_requirements
    detect_installed_services
    select_web_server
    select_database
    install_php_fpm
    
    # Create required directories before installation
    create_required_directories
    
    # Install selected services
    install_web_server
    install_database
    install_dns_server
    install_mail_server
    install_certbot
    install_firewall
    
    # Save configuration and show summary
    save_installation_config
}
