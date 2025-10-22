#!/bin/bash

################################################################################
# EasyPanel - Settings Script
# System configuration and settings management
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

################################################################################
# Settings Functions
################################################################################

# Show current configuration
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
    
    echo -e "${BOLD}Service Status:${NC}"
    
    local services=("nginx" "apache2" "mariadb" "mysql" "bind9" "postfix" "dovecot")
    for service in "${services[@]}"; do
        if package_installed "$service"; then
            if service_running "$service"; then
                echo -e "  $service: ${GREEN}✓${NC}"
            else
                echo -e "  $service: ${YELLOW}●${NC}"
            fi
        fi
    done
    
    echo ""
    pause_menu
}

# Manage services
manage_services() {
    print_header "Service Management"
    
    local -a installed_services
    
    local services=("nginx" "apache2" "mariadb" "mysql" "bind9" "postfix" "dovecot" "php-fpm")
    
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

# System information
show_system_info() {
    print_header "System Information"
    
    echo -e "${BOLD}Hostname:${NC}"
    echo "  $(hostname)"
    echo ""
    
    echo -e "${BOLD}Operating System:${NC}"
    source /etc/os-release
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

# Change root database password
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
        $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
        print_success "Database root password changed"
        
        # Update configuration
        set_config "DB_ROOT_PASSWORD" "$new_password"
    else
        print_error "Failed to change password"
    fi
    
    pause_menu
}

# Firewall configuration
configure_firewall() {
    print_header "Firewall Configuration"
    
    if ! command_exists "ufw"; then
        print_error "UFW firewall not installed"
        if prompt_yes_no "Install UFW?"; then
            apt-get install -y ufw >/dev/null 2>&1
            ufw --force enable >/dev/null 2>&1
            print_success "UFW installed and enabled"
        fi
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

# Log viewer
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

# Security settings
security_settings() {
    print_header "Security Settings"
    
    echo -e "  ${CYAN}1)${NC} Install fail2ban"
    echo -e "  ${CYAN}2)${NC} Configure SSH"
    echo -e "  ${CYAN}3)${NC} System updates"
    echo -e "  ${CYAN}4)${NC} View installed packages"
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
            if prompt_yes_no "Change SSH port?"; then
                local ssh_port=$(get_input "New SSH port" "22")
                # Add SSH configuration logic here
                print_info "SSH port configuration would go here"
            fi
            ;;
        3)
            print_info "Checking for updates..."
            apt-get update >/dev/null 2>&1
            apt-get upgrade -y 2>&1 | tail -5
            print_success "System updated"
            ;;
        4)
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

# About
show_about() {
    print_header "About EasyPanel"
    
    cat << 'EOF'

EasyPanel v1.0.0
Terminal-based Web Server Control Panel

A comprehensive solution for managing web servers, domains, databases,
mail servers, and more from the command line.

Features:
  • Domain management with SSL certificates
  • Apache2 and Nginx support
  • MySQL and MariaDB management
  • Mail server configuration
  • DNS zone management
  • Cron job scheduling
  • Automated backups
  • Firewall management

Copyright © 2025 EasyPanel Contributors
License: MIT

For more information, visit: https://github.com/easypanel/easypanel

EOF
    
    pause_menu
}

################################################################################
# Main Settings Menu
################################################################################

settings_menu() {
    while true; do
        print_header "Settings"
        
        echo -e "  ${CYAN}1)${NC} Show Configuration"
        echo -e "  ${CYAN}2)${NC} Manage Services"
        echo -e "  ${CYAN}3)${NC} System Information"
        echo -e "  ${CYAN}4)${NC} Change Database Password"
        echo -e "  ${CYAN}5)${NC} Firewall Configuration"
        echo -e "  ${CYAN}6)${NC} View Logs"
        echo -e "  ${CYAN}7)${NC} Security Settings"
        echo -e "  ${CYAN}8)${NC} About"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) show_configuration ;;
            2) manage_services ;;
            3) show_system_info ;;
            4) change_db_password ;;
            5) configure_firewall ;;
            6) view_logs ;;
            7) security_settings ;;
            8) show_about ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}
