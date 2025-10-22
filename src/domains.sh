#!/bin/bash

################################################################################
# EasyPanel - Domain Management Script
# Manage domains, create virtual hosts, handle SSL certificates
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

################################################################################
# Domain Functions
################################################################################

# List all domains
show_domains_list() {
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
        local domain_path="$WEBSITES_ROOT/$domain"
        local config_file=""
        
        case "$(get_config "WEB_SERVER")" in
            apache2)
                config_file="/etc/apache2/sites-available/$domain.conf"
                ;;
            nginx)
                config_file="/etc/nginx/sites-available/$domain"
                ;;
        esac
        
        echo -e "  ${CYAN}•${NC} $domain"
        echo "      Root: $domain_path/htdocs"
        
        if [ -f "$config_file" ]; then
            echo -e "      Config: ${GREEN}Configured${NC}"
        else
            echo -e "      Config: ${RED}Missing${NC}"
        fi
        
        echo ""
    done
    
    pause_menu
}

# Add new domain
add_domain() {
    print_header "Add New Domain"
    
    # Get domain name
    while true; do
        local domain=$(get_input "Enter domain name" "example.com")
        
        if validate_domain "$domain"; then
            # Check if already exists
            if [ -d "$WEBSITES_ROOT/$domain" ]; then
                print_warning "Domain already exists"
                if ! prompt_yes_no "Configure existing domain?"; then
                    return
                fi
            fi
            break
        fi
    done
    
    # Ask for DNS support
    local dns_support="0"
    if prompt_yes_no "Add DNS support for this domain?"; then
        dns_support="1"
    fi
    
    # Ask for mail support
    local mail_support="0"
    if prompt_yes_no "Add mail support for this domain?"; then
        mail_support="1"
    fi
    
    # Create domain structure
    create_domain_structure "$domain"
    
    # Create web server configuration
    create_web_config "$domain"
    
    # Enable domain
    enable_domain "$domain"
    
    # Get SSL certificate
    if prompt_yes_no "Install SSL certificate with Let's Encrypt?"; then
        install_ssl_certificate "$domain"
    fi
    
    # Save domain configuration
    save_domain_config "$domain" "$dns_support" "$mail_support"
    
    print_success "Domain '$domain' added successfully!"
    pause_menu
}

# Create web server configuration
create_web_config() {
    local domain="$1"
    local web_server=$(get_config "WEB_SERVER")
    
    case "$web_server" in
        apache2)
            create_apache_config "$domain"
            ;;
        nginx)
            create_nginx_config "$domain"
            ;;
        *)
            print_error "Web server not configured"
            return 1
            ;;
    esac
}

# Create Apache configuration for domain
create_apache_config() {
    local domain="$1"
    local config_file="/etc/apache2/sites-available/$domain.conf"
    local php_version=$(php -r 'echo PHP_VERSION_ID;' 2>/dev/null | head -c 3 || echo "80")
    
    cat > "$config_file" << EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    ServerAdmin admin@$domain
    
    DocumentRoot /root/websites/$domain/htdocs
    
    # Custom configuration
    Include /root/websites/$domain/config/*.conf
    
    # Log files
    ErrorLog /root/websites/$domain/logs/error.log
    CustomLog /root/websites/$domain/logs/access.log combined
    
    # PHP-FPM configuration
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php${php_version}-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    # Directory permissions
    <Directory /root/websites/$domain/htdocs>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Rewrite rules
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteBase /
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]
    </IfModule>
</VirtualHost>

# HTTPS configuration (will be updated by Let's Encrypt)
<VirtualHost *:443>
    ServerName $domain
    ServerAlias www.$domain
    ServerAdmin admin@$domain
    
    DocumentRoot /root/websites/$domain/htdocs
    
    Include /root/websites/$domain/config/*.conf
    
    ErrorLog /root/websites/$domain/logs/error.log
    CustomLog /root/websites/$domain/logs/access.log combined
    
    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/php/php${php_version}-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    <Directory /root/websites/$domain/htdocs>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteBase /
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]
    </IfModule>
    
    SSLEngine on
    SSLCertificateFile /root/websites/$domain/certificates/cert.pem
    SSLCertificateKeyFile /root/websites/$domain/certificates/privkey.pem
    SSLCertificateChainFile /root/websites/$domain/certificates/chain.pem
</VirtualHost>
EOF
    
    chmod 644 "$config_file"
    print_success "Created Apache configuration for $domain"
}

# Create Nginx configuration for domain
create_nginx_config() {
    local domain="$1"
    local config_file="/etc/nginx/sites-available/$domain"
    local php_version=$(php -r 'echo PHP_VERSION_ID;' 2>/dev/null | head -c 3 || echo "80")
    
    cat > "$config_file" << EOF
upstream php${php_version} {
    server unix:/run/php/php${php_version}-fpm.sock;
}

server {
    listen 80;
    listen [::]:80;
    
    server_name $domain www.$domain;
    root /root/websites/$domain/htdocs;
    index index.php index.html index.htm;
    
    error_log /root/websites/$domain/logs/error.log;
    access_log /root/websites/$domain/logs/access.log;
    
    # Custom configuration
    include /root/websites/$domain/config/*.conf;
    
    # PHP-FPM configuration
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass php${php_version};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param HTTPS off;
    }
    
    # Static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Remove access to hidden files
    location ~ /\. {
        deny all;
    }
    
    # Default rewrite
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}

# HTTPS configuration (will be updated by Let's Encrypt)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    server_name $domain www.$domain;
    root /root/websites/$domain/htdocs;
    index index.php index.html index.htm;
    
    error_log /root/websites/$domain/logs/error.log;
    access_log /root/websites/$domain/logs/access.log;
    
    ssl_certificate /root/websites/$domain/certificates/fullchain.pem;
    ssl_certificate_key /root/websites/$domain/certificates/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    include /root/websites/$domain/config/*.conf;
    
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass php${php_version};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param HTTPS on;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location ~ /\. {
        deny all;
    }
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    
    location /.well-known/acme-challenge/ {
        root /root/websites/$domain/htdocs;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    chmod 644 "$config_file"
    print_success "Created Nginx configuration for $domain"
}

# Enable domain
enable_domain() {
    local domain="$1"
    local web_server=$(get_config "WEB_SERVER")
    
    case "$web_server" in
        apache2)
            a2ensite "$domain" >/dev/null 2>&1
            apache2ctl -t >/dev/null 2>&1 && {
                restart_service "apache2"
                print_success "Enabled Apache site: $domain"
            } || print_error "Apache configuration test failed"
            ;;
        nginx)
            ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain" 2>/dev/null
            nginx -t >/dev/null 2>&1 && {
                restart_service "nginx"
                print_success "Enabled Nginx site: $domain"
            } || print_error "Nginx configuration test failed"
            ;;
    esac
}

# Disable domain
disable_domain() {
    local domain="$1"
    local web_server=$(get_config "WEB_SERVER")
    
    case "$web_server" in
        apache2)
            a2dissite "$domain" >/dev/null 2>&1
            restart_service "apache2"
            print_success "Disabled Apache site: $domain"
            ;;
        nginx)
            rm -f "/etc/nginx/sites-enabled/$domain"
            restart_service "nginx"
            print_success "Disabled Nginx site: $domain"
            ;;
    esac
}

# Install SSL certificate
install_ssl_certificate() {
    local domain="$1"
    
    print_info "Installing SSL certificate with Let's Encrypt..."
    
    local web_server=$(get_config "WEB_SERVER")
    local certbot_plugin="apache" # default
    
    if [ "$web_server" = "nginx" ]; then
        certbot_plugin="nginx"
    fi
    
    if certbot certonly --${certbot_plugin} -d "$domain" -d "www.$domain" \
        --non-interactive --agree-tos -m admin@${domain} 2>/dev/null; then
        
        # Copy certificates to domain directory
        copy_ssl_certificates_local "$domain"
        
        # Update web server configuration if needed
        if [ "$web_server" = "apache2" ]; then
            a2enmod ssl 2>/dev/null
            restart_service "apache2"
        else
            restart_service "nginx"
        fi
        
        print_success "SSL certificate installed for $domain"
    else
        print_error "Failed to install SSL certificate"
        return 1
    fi
}

# Renew SSL certificate
renew_ssl_certificate() {
    local domain="$1"
    
    print_info "Renewing SSL certificate for $domain..."
    
    if certbot renew --cert-name "$domain" --non-interactive 2>/dev/null; then
        # Copy updated certificates to domain directory
        copy_ssl_certificates_local "$domain"
        
        print_success "SSL certificate renewed for $domain"
    else
        print_error "Failed to renew SSL certificate"
        return 1
    fi
}

# Edit domain configuration
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
    
    echo -e "  ${CYAN}1)${NC} Edit web server configuration"
    echo -e "  ${CYAN}2)${NC} View error log"
    echo -e "  ${CYAN}3)${NC} View access log"
    echo -e "  ${CYAN}4)${NC} Renew SSL certificate"
    echo -e "  ${CYAN}5)${NC} View domain info"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            local web_server=$(get_config "WEB_SERVER")
            if [ "$web_server" = "apache2" ]; then
                ${EDITOR:-nano} "/etc/apache2/sites-available/$domain.conf"
            else
                ${EDITOR:-nano} "/etc/nginx/sites-available/$domain"
            fi
            ;;
        2)
            ${EDITOR:-less} "$WEBSITES_ROOT/$domain/logs/error.log"
            ;;
        3)
            ${EDITOR:-less} "$WEBSITES_ROOT/$domain/logs/access.log"
            ;;
        4)
            renew_ssl_certificate "$domain"
            pause_menu
            ;;
        5)
            show_domain_info "$domain"
            ;;
        0)
            return
            ;;
    esac
}

# Show domain information
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
    echo ""
    
    echo -e "${BOLD}Web Server:${NC}"
    local web_server=$(get_config "WEB_SERVER")
    echo "  $web_server"
    echo ""
    
    if [ "$web_server" = "apache2" ]; then
        if a2query -s "$domain" >/dev/null 2>&1; then
            echo -e "  Status: ${GREEN}Enabled${NC}"
        else
            echo -e "  Status: ${YELLOW}Disabled${NC}"
        fi
    else
        if [ -L "/etc/nginx/sites-enabled/$domain" ]; then
            echo -e "  Status: ${GREEN}Enabled${NC}"
        else
            echo -e "  Status: ${YELLOW}Disabled${NC}"
        fi
    fi
    echo ""
    
    echo -e "${BOLD}SSL Certificate:${NC}"
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        echo -e "  ${GREEN}✓ Installed${NC}"
        local expiry=$(openssl x509 -in "/etc/letsencrypt/live/$domain/fullchain.pem" -noout -enddate | cut -d= -f2)
        echo "  Expires: $expiry"
    else
        echo -e "  ${RED}✗ Not installed${NC}"
    fi
    echo ""
    
    pause_menu
}

# Delete domain
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
    if ! prompt_yes_no "Continue?"; then
        print_info "Cancelled"
        pause_menu
        return
    fi
    
    # Disable domain
    disable_domain "$domain"
    
    # Remove web server configuration
    local web_server=$(get_config "WEB_SERVER")
    case "$web_server" in
        apache2)
            rm -f "/etc/apache2/sites-available/$domain.conf"
            ;;
        nginx)
            rm -f "/etc/nginx/sites-available/$domain"
            rm -f "/etc/nginx/sites-enabled/$domain"
            ;;
    esac
    
    # Remove domain files
    remove_domain_structure "$domain"
    
    # Remove SSL certificate
    certbot delete --cert-name "$domain" --non-interactive 2>/dev/null
    
    print_success "Domain deleted: $domain"
    pause_menu
}

# Save domain configuration
save_domain_config() {
    local domain="$1"
    local dns_support="$2"
    local mail_support="$3"
    
    local config_file="$WEBSITES_ROOT/$domain/.easypanel"
    
    cat > "$config_file" << EOF
# Domain Configuration
DOMAIN="$domain"
DNS_SUPPORT="$dns_support"
MAIL_SUPPORT="$mail_support"
CREATED_DATE="$(date)"
EOF
    
    chmod 600 "$config_file"
}

################################################################################
# Main Domain Menu
################################################################################

domains_menu() {
    while true; do
        print_header "Domain Management"
        
        echo -e "  ${CYAN}1)${NC} List Domains"
        echo -e "  ${CYAN}2)${NC} Add Domain"
        echo -e "  ${CYAN}3)${NC} Edit Domain"
        echo -e "  ${CYAN}4)${NC} Delete Domain"
        echo -e "  ${CYAN}5)${NC} Domain Information"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-5]: " choice
        
        case "$choice" in
            1) show_domains_list ;;
            2) add_domain ;;
            3) edit_domain ;;
            4) delete_domain ;;
            5) 
                local domains=($(list_domains))
                if [ ${#domains[@]} -gt 0 ]; then
                    echo "Select domain:"
                    for i in "${!domains[@]}"; do
                        echo -e "  ${CYAN}$((i+1)))${NC} ${domains[$i]}"
                    done
                    read -p "Enter selection: " sel
                    [ $sel -ge 1 ] && [ $sel -le ${#domains[@]} ] && show_domain_info "${domains[$((sel-1))]}"
                fi
                ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}
