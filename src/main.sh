#!/bin/bash

################################################################################
# EasyPanel - Main Entry Point
# Terminal-based web server control panel
# Usage: easypanel [command]
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PANEL_VERSION="1.0.0"

# Determine library path (installed or development)
if [ -f "/usr/local/lib/easypanel/utils.sh" ]; then
    # Installed system-wide
    LIB_PATH="/usr/local/lib/easypanel/utils.sh"
    MODULES_DIR="/usr/local/lib/easypanel/modules"
elif [ -f "${SCRIPT_DIR}/../lib/utils.sh" ]; then
    # Development/local mode
    LIB_PATH="${SCRIPT_DIR}/../lib/utils.sh"
    MODULES_DIR="${SCRIPT_DIR}"
else
    echo "Error: Cannot find utility functions"
    exit 1
fi

# Source utilities
source "$LIB_PATH" || {
    echo "Error: Cannot source utility functions from $LIB_PATH"
    exit 1
}

# Source scripts
source_script() {
    local script="$1"
    local script_path=""
    
    # Try installed location first
    if [ -f "/usr/local/lib/easypanel/modules/$script" ]; then
        script_path="/usr/local/lib/easypanel/modules/$script"
    # Then try local directory
    elif [ -f "${SCRIPT_DIR}/${script}" ]; then
        script_path="${SCRIPT_DIR}/${script}"
    else
        print_error "Script not found: $script"
        return 1
    fi
    
    source "$script_path"
}

################################################################################
# Main Menu Functions
################################################################################

# Main menu
show_main_menu() {
    while true; do
        print_header "EasyPanel v${PANEL_VERSION} - Web Server Control Panel"
        
        echo -e "  ${CYAN}1)${NC} Install/Setup"
        echo -e "  ${CYAN}2)${NC} Manage Domains"
        echo -e "  ${CYAN}3)${NC} Manage DNS"
        echo -e "  ${CYAN}4)${NC} Manage Mail"
        echo -e "  ${CYAN}5)${NC} Manage Databases"
        echo -e "  ${CYAN}6)${NC} Manage Cron Jobs"
        echo -e "  ${CYAN}7)${NC} Backup & Restore"
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
            6) submenu_cron ;;
            7) submenu_backup ;;
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

# Install submenu
submenu_install() {
    if ! source_script "install.sh"; then
        print_error "Failed to load install module"
        return
    fi
    if ! type install_menu &>/dev/null; then
        print_error "install_menu function not found"
        return
    fi
    install_menu
}

# Domains submenu
submenu_domains() {
    if ! source_script "domains.sh"; then
        print_error "Failed to load domains module"
        return
    fi
    if ! type domains_menu &>/dev/null; then
        print_error "domains_menu function not found"
        return
    fi
    domains_menu
}

# DNS submenu
submenu_dns() {
    if ! source_script "dns.sh"; then
        print_error "Failed to load dns module"
        return
    fi
    if ! type dns_menu &>/dev/null; then
        print_error "dns_menu function not found"
        return
    fi
    dns_menu
}

# Mail submenu
submenu_mail() {
    if ! source_script "mail.sh"; then
        print_error "Failed to load mail module"
        return
    fi
    if ! type mail_menu &>/dev/null; then
        print_error "mail_menu function not found"
        return
    fi
    mail_menu
}

# Databases submenu
submenu_databases() {
    if ! source_script "databases.sh"; then
        print_error "Failed to load databases module"
        return
    fi
    if ! type databases_menu &>/dev/null; then
        print_error "databases_menu function not found"
        return
    fi
    databases_menu
}

# Cron submenu
submenu_cron() {
    if ! source_script "cron.sh"; then
        print_error "Failed to load cron module"
        return
    fi
    if ! type cron_menu &>/dev/null; then
        print_error "cron_menu function not found"
        return
    fi
    cron_menu
}

# Backup submenu
submenu_backup() {
    if ! source_script "backup.sh"; then
        print_error "Failed to load backup module"
        return
    fi
    if ! type backup_menu &>/dev/null; then
        print_error "backup_menu function not found"
        return
    fi
    backup_menu
}

# Settings submenu
submenu_settings() {
    if ! source_script "settings.sh"; then
        print_error "Failed to load settings module"
        return
    fi
    if ! type settings_menu &>/dev/null; then
        print_error "settings_menu function not found"
        return
    fi
    settings_menu
}

# System status
show_system_status() {
    print_header "System Status"
    
    local web_server=$(get_config "WEB_SERVER" "Not installed")
    local database=$(get_config "DATABASE" "Not installed")
    
    echo -e "${BOLD}Web Server:${NC}"
    echo "  Type: $web_server"
    if [ "$web_server" != "Not installed" ]; then
        if service_running "$web_server"; then
            echo -e "  Status: ${GREEN}Running${NC}"
        else
            echo -e "  Status: ${RED}Stopped${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}Database Server:${NC}"
    echo "  Type: $database"
    if [ "$database" != "Not installed" ]; then
        if service_running "$database"; then
            echo -e "  Status: ${GREEN}Running${NC}"
        else
            echo -e "  Status: ${RED}Stopped${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}Services:${NC}"
    
    # Check various services
    local services=("nginx" "apache2" "php-fpm" "bind9" "postfix" "dovecot" "mysql" "mariadb" "fail2ban")
    
    for service in "${services[@]}"; do
        if service_running "$service"; then
            echo -e "  $service: ${GREEN}✓${NC}"
        elif package_installed "$service"; then
            echo -e "  $service: ${YELLOW}●${NC} (Installed but stopped)"
        fi
    done
    
    echo ""
    echo -e "${BOLD}Domains:${NC}"
    local domain_count=$(list_domains | wc -l)
    if [ $domain_count -gt 0 ]; then
        echo "  Total: $domain_count"
        echo ""
        list_domains | head -5 | while read domain; do
            echo "    • $domain"
        done
        if [ $domain_count -gt 5 ]; then
            echo "    ... and $(($domain_count - 5)) more"
        fi
    else
        echo "  No domains configured"
    fi
    
    echo ""
    pause_menu
}

################################################################################
# Command Line Arguments
################################################################################

# Handle command line arguments
handle_arguments() {
    case "${1:-menu}" in
        install)
            check_root
            init_logging
            source_script "install.sh" || exit 1
            run_installation
            ;;
        domains)
            check_root
            init_logging
            source_script "domains.sh" || exit 1
            domains_menu
            ;;
        dns)
            check_root
            init_logging
            source_script "dns.sh" || exit 1
            dns_menu
            ;;
        mail)
            check_root
            init_logging
            source_script "mail.sh" || exit 1
            mail_menu
            ;;
        databases)
            check_root
            init_logging
            source_script "databases.sh" || exit 1
            databases_menu
            ;;
        cron)
            check_root
            init_logging
            source_script "cron.sh" || exit 1
            cron_menu
            ;;
        backup)
            check_root
            init_logging
            source_script "backup.sh" || exit 1
            backup_menu
            ;;
        status)
            check_root
            init_logging
            show_system_status
            ;;
        version)
            echo "EasyPanel v${PANEL_VERSION}"
            ;;
        help)
            show_help
            ;;
        *)
            show_help
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
${CYAN}${BOLD}EasyPanel v${PANEL_VERSION} - Terminal-based Web Server Control Panel${NC}

${BOLD}Usage:${NC}
  easypanel [command]

${BOLD}Commands:${NC}
  (no arguments)  Interactive menu
  install         Run installation wizard
  domains         Manage domains
  dns             Manage DNS records
  mail            Manage mail accounts
  databases       Manage databases
  cron            Manage cron jobs
  backup          Backup and restore
  status          Show system status
  version         Show version
  help            Show this help message

${BOLD}Examples:${NC}
  easypanel                    # Start interactive menu
  easypanel install            # Run installation wizard
  easypanel domains            # Go directly to domains management
  easypanel status             # Show system status

${BOLD}Configuration:${NC}
  Config file: /etc/easypanel/config
  Log file:    /var/log/easypanel.log
  Data root:   /root/websites

EOF
}

################################################################################
# Main Execution
################################################################################

# Check root
check_root

# Initialize logging
init_logging

# Initialize configuration
init_config

# Handle arguments or show interactive menu
if [ $# -gt 0 ]; then
    handle_arguments "$@"
else
    show_main_menu
fi
