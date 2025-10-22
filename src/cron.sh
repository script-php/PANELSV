#!/bin/bash

################################################################################
# EasyPanel - Cron Job Management Script
# Manage system cron jobs
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

CRON_CONFIG_DIR="/etc/easypanel/cron"

################################################################################
# Cron Functions
################################################################################

# Initialize cron system
init_cron() {
    mkdir -p "$CRON_CONFIG_DIR"
    chmod 755 "$CRON_CONFIG_DIR"
}

# List cron jobs
list_cron_jobs() {
    print_header "Cron Jobs"
    
    local count=0
    
    echo -e "${BOLD}System Cron Jobs:${NC}"
    echo ""
    
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
    echo -e "${BOLD}Custom Cron Jobs:${NC}"
    echo ""
    
    if [ -d "$CRON_CONFIG_DIR" ] && [ "$(ls -A "$CRON_CONFIG_DIR")" ]; then
        ls -1 "$CRON_CONFIG_DIR" | while read job_file; do
            echo -e "  ${CYAN}•${NC} $job_file"
            cat "$CRON_CONFIG_DIR/$job_file" | sed 's/^/    /'
            echo ""
        done
    else
        print_info "No custom cron jobs"
    fi
    
    pause_menu
}

# Add cron job
add_cron_job() {
    print_header "Add Cron Job"
    
    echo -e "${BOLD}Select job type:${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Website backup"
    echo -e "  ${CYAN}2)${NC} Database backup"
    echo -e "  ${CYAN}3)${NC} SSL certificate renewal"
    echo -e "  ${CYAN}4)${NC} Log rotation"
    echo -e "  ${CYAN}5)${NC} System update check"
    echo -e "  ${CYAN}6)${NC} Custom command"
    echo ""
    
    read -p "Select type [1-6]: " type_choice
    
    case "$type_choice" in
        1) add_website_backup_cron ;;
        2) add_database_backup_cron ;;
        3) add_ssl_renewal_cron ;;
        4) add_log_rotation_cron ;;
        5) add_update_check_cron ;;
        6) add_custom_cron ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause_menu
}

# Add website backup cron
add_website_backup_cron() {
    print_info "Website backup will be performed daily"
    
    local hour=$(get_input "Hour (0-23)" "2")
    local minute=$(get_input "Minute (0-59)" "0")
    
    local command="$minute $hour * * * root /root/easypanel_backup.sh websites"
    
    # Create backup script if not exists
    create_backup_script
    
    # Add to root crontab
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    
    print_success "Website backup cron job added"
}

# Add database backup cron
add_database_backup_cron() {
    print_info "Database backup will be performed daily"
    
    local hour=$(get_input "Hour (0-23)" "3")
    local minute=$(get_input "Minute (0-59)" "0")
    
    local command="$minute $hour * * * root /root/easypanel_backup.sh databases"
    
    create_backup_script
    
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    
    print_success "Database backup cron job added"
}

# Add SSL renewal cron
add_ssl_renewal_cron() {
    print_info "SSL certificates will be renewed automatically"
    
    local command="0 3 * * * root /root/easypanel_ssl_renew.sh"
    
    create_ssl_renewal_script
    
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    
    print_success "SSL renewal cron job added"
}

# Add log rotation cron
add_log_rotation_cron() {
    print_info "Logs will be rotated daily"
    
    local command="0 2 * * * root /usr/sbin/logrotate /etc/logrotate.conf"
    
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    
    print_success "Log rotation cron job added"
}

# Add update check cron
add_update_check_cron() {
    print_info "System updates will be checked daily"
    
    local command="0 6 * * 0 root apt-get update >/dev/null 2>&1"
    
    (crontab -u root -l 2>/dev/null; echo "$command") | crontab -u root - 2>/dev/null
    
    print_success "Update check cron job added"
}

# Add custom cron
add_custom_cron() {
    print_header "Add Custom Cron Job"
    
    echo "Cron format: minute hour day month weekday command"
    echo "Example: 0 2 * * * /home/user/backup.sh (daily at 2:00 AM)"
    echo ""
    
    local job_name=$(get_input "Job name (no spaces)")
    local schedule=$(get_input "Cron schedule")
    local command=$(get_input "Command to execute")
    local user=$(get_input "Run as user" "root")
    
    # Validate cron schedule format (basic validation)
    if ! [[ $schedule =~ ^(\*|[0-9]{1,2}|[0-9]{1,2}(,[0-9]{1,2})*)(\ +(\*|[0-9]{1,2}|[0-9]{1,2}(,[0-9]{1,2})*))+$ ]]; then
        print_warning "Cron schedule format may be invalid (continuing anyway)"
    fi
    
    # Save custom cron job
    cat > "$CRON_CONFIG_DIR/$job_name.cron" << EOF
# Custom Cron Job: $job_name
# Added: $(date)
$schedule $command
EOF
    
    # Add to crontab
    (crontab -u "$user" -l 2>/dev/null; echo "$schedule $command") | crontab -u "$user" - 2>/dev/null
    
    print_success "Custom cron job added: $job_name"
}

# Edit cron job
edit_cron_job() {
    print_header "Edit Cron Job"
    
    local -a jobs
    local count=0
    
    # Get system cron jobs
    for user in root www-data; do
        local crontab=$(crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$")
        if [ -n "$crontab" ]; then
            while IFS= read -r line; do
                jobs+=("[$user] $line")
                ((count++))
            done <<< "$crontab"
        fi
    done
    
    if [ ${#jobs[@]} -eq 0 ]; then
        print_info "No cron jobs found"
        pause_menu
        return
    fi
    
    echo "Select cron job to edit:"
    echo ""
    
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
    
    # Edit crontab
    if prompt_yes_no "Edit crontab interactively?"; then
        local user=$(echo "${jobs[$((selection-1))]}" | cut -d']' -f1 | tr -d '[')
        crontab -u "$user" -e
        print_success "Crontab updated"
    fi
    
    pause_menu
}

# Delete cron job
delete_cron_job() {
    print_header "Delete Cron Job"
    
    local -a jobs
    
    for user in root www-data; do
        local crontab=$(crontab -u "$user" -l 2>/dev/null | grep -v "^#" | grep -v "^$")
        if [ -n "$crontab" ]; then
            while IFS= read -r line; do
                jobs+=("$user|$line")
            done <<< "$crontab"
        fi
    done
    
    if [ ${#jobs[@]} -eq 0 ]; then
        print_info "No cron jobs found"
        pause_menu
        return
    fi
    
    echo "Select cron job to delete:"
    echo ""
    
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
    local user="${job_to_delete%%|*}"
    local schedule="${job_to_delete##*|}"
    
    if prompt_yes_no "Delete this cron job?"; then
        # Remove from crontab
        (crontab -u "$user" -l 2>/dev/null | grep -v "$schedule") | crontab -u "$user" - 2>/dev/null
        print_success "Cron job deleted"
    fi
    
    pause_menu
}

# Create backup script
create_backup_script() {
    local script_file="/root/easypanel_backup.sh"
    
    if [ -f "$script_file" ]; then
        return
    fi
    
    cat > "$script_file" << 'SCRIPT_EOF'
#!/bin/bash

BACKUP_ROOT="/root/backups"
mkdir -p "$BACKUP_ROOT"

case "$1" in
    websites)
        echo "Backing up websites..."
        tar -czf "$BACKUP_ROOT/websites_$(date +%Y%m%d_%H%M%S).tar.gz" /root/websites >/dev/null 2>&1
        ;;
    databases)
        echo "Backing up databases..."
        mysqldump --all-databases -u root -proot | gzip > "$BACKUP_ROOT/databases_$(date +%Y%m%d_%H%M%S).sql.gz"
        ;;
esac

# Keep only last 7 days of backups
find "$BACKUP_ROOT" -type f -mtime +7 -delete
SCRIPT_EOF
    
    chmod 755 "$script_file"
}

# Create SSL renewal script
create_ssl_renewal_script() {
    local script_file="/root/easypanel_ssl_renew.sh"
    
    if [ -f "$script_file" ]; then
        return
    fi
    
    cat > "$script_file" << 'SCRIPT_EOF'
#!/bin/bash

# Source EasyPanel utilities
source /usr/local/lib/easypanel/utils.sh

# Renew all certificates
certbot renew --non-interactive --quiet 2>/dev/null

# Copy renewed certificates to domain directories
WEBSITES_ROOT="/root/websites"
if [ -d "$WEBSITES_ROOT" ]; then
    for domain_dir in "$WEBSITES_ROOT"/*; do
        if [ -d "$domain_dir" ]; then
            domain=$(basename "$domain_dir")
            cert_source="/etc/letsencrypt/live/$domain"
            cert_dest="$domain_dir/certificates"
            
            if [ -d "$cert_source" ] && [ -d "$cert_dest" ]; then
                cp -r "$cert_source"/* "$cert_dest/" 2>/dev/null
                chmod 644 "$cert_dest"/*.pem 2>/dev/null
                chmod 600 "$cert_dest"/privkey.pem 2>/dev/null
                chown -R root:root "$cert_dest" 2>/dev/null
            fi
        fi
    done
fi

# Reload web servers to use updated certificates
systemctl reload apache2 2>/dev/null
systemctl reload nginx 2>/dev/null
SCRIPT_EOF
    
    chmod 755 "$script_file"
}

################################################################################
# Main Cron Menu
################################################################################

cron_menu() {
    init_cron
    
    while true; do
        print_header "Cron Job Management"
        
        echo -e "  ${CYAN}1)${NC} List Cron Jobs"
        echo -e "  ${CYAN}2)${NC} Add Cron Job"
        echo -e "  ${CYAN}3)${NC} Edit Cron Job"
        echo -e "  ${CYAN}4)${NC} Delete Cron Job"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-4]: " choice
        
        case "$choice" in
            1) list_cron_jobs ;;
            2) add_cron_job ;;
            3) edit_cron_job ;;
            4) delete_cron_job ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}
