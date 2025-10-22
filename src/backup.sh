#!/bin/bash

################################################################################
# EasyPanel - Backup Management Script
# Manage system and database backups
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

BACKUP_ROOT="/root/backups"
BACKUP_CONFIG_DIR="/etc/easypanel/backup"

################################################################################
# Backup Functions
################################################################################

# Initialize backup system
init_backup() {
    mkdir -p "$BACKUP_ROOT"/{websites,databases,full,logs}
    mkdir -p "$BACKUP_CONFIG_DIR"
    chmod 700 "$BACKUP_ROOT"
}

# Create website backup
backup_websites() {
    print_header "Website Backup"
    
    local backup_dir="$BACKUP_ROOT/websites"
    local domains=($(list_domains))
    
    if [ ${#domains[@]} -eq 0 ]; then
        print_info "No domains to backup"
        pause_menu
        return
    fi
    
    echo "Select backup type:"
    echo ""
    echo -e "  ${CYAN}1)${NC} Backup all domains"
    echo -e "  ${CYAN}2)${NC} Backup specific domain"
    echo ""
    
    read -p "Select option [1-2]: " choice
    
    case "$choice" in
        1)
            print_info "Backing up all domains (this may take a while)..."
            local backup_file="$backup_dir/websites_full_$(date +%Y%m%d_%H%M%S).tar.gz"
            
            if tar -czf "$backup_file" /root/websites 2>/dev/null; then
                local size=$(du -h "$backup_file" | cut -f1)
                print_success "Backup completed: $backup_file ($size)"
            else
                print_error "Backup failed"
            fi
            ;;
        2)
            echo "Select domain to backup:"
            for i in "${!domains[@]}"; do
                echo -e "  ${CYAN}$((i+1)))${NC} ${domains[$i]}"
            done
            echo ""
            
            read -p "Enter selection: " sel
            
            if [[ $sel =~ ^[0-9]+$ ]] && [ $sel -ge 1 ] && [ $sel -le ${#domains[@]} ]; then
                local domain="${domains[$((sel-1))]}"
                local backup_file="$backup_dir/website_${domain}_$(date +%Y%m%d_%H%M%S).tar.gz"
                
                print_info "Backing up domain: $domain..."
                
                if tar -czf "$backup_file" "/root/websites/$domain" 2>/dev/null; then
                    local size=$(du -h "$backup_file" | cut -f1)
                    print_success "Backup completed: $backup_file ($size)"
                else
                    print_error "Backup failed"
                fi
            else
                print_error "Invalid selection"
            fi
            ;;
    esac
    
    pause_menu
}

# Create database backup
backup_databases() {
    print_header "Database Backup"
    
    local db_cmd=$(get_db_command)
    local backup_dir="$BACKUP_ROOT/databases"
    
    echo "Select backup type:"
    echo ""
    echo -e "  ${CYAN}1)${NC} Backup all databases"
    echo -e "  ${CYAN}2)${NC} Backup specific database"
    echo ""
    
    read -p "Select option [1-2]: " choice
    
    case "$choice" in
        1)
            print_info "Backing up all databases..."
            local backup_file="$backup_dir/all_databases_$(date +%Y%m%d_%H%M%S).sql.gz"
            
            if $db_cmd -u root -proot --all-databases 2>/dev/null | gzip > "$backup_file"; then
                local size=$(du -h "$backup_file" | cut -f1)
                print_success "Backup completed: $backup_file ($size)"
            else
                print_error "Backup failed"
            fi
            ;;
        2)
            local -a databases
            while IFS= read -r db; do
                if [[ ! "$db" =~ ^(information_schema|mysql|performance_schema|sys)$ ]]; then
                    databases+=("$db")
                fi
            done < <($db_cmd -u root -proot -e "SHOW DATABASES;" 2>/dev/null | tail -n +2)
            
            if [ ${#databases[@]} -eq 0 ]; then
                print_info "No databases to backup"
                pause_menu
                return
            fi
            
            echo "Select database:"
            for i in "${!databases[@]}"; do
                echo -e "  ${CYAN}$((i+1)))${NC} ${databases[$i]}"
            done
            echo ""
            
            read -p "Enter selection: " sel
            
            if [[ $sel =~ ^[0-9]+$ ]] && [ $sel -ge 1 ] && [ $sel -le ${#databases[@]} ]; then
                local database="${databases[$((sel-1))]}"
                local backup_file="$backup_dir/db_${database}_$(date +%Y%m%d_%H%M%S).sql.gz"
                
                print_info "Backing up database: $database..."
                
                if $db_cmd -u root -proot "$database" 2>/dev/null | gzip > "$backup_file"; then
                    local size=$(du -h "$backup_file" | cut -f1)
                    print_success "Backup completed: $backup_file ($size)"
                else
                    print_error "Backup failed"
                fi
            else
                print_error "Invalid selection"
            fi
            ;;
    esac
    
    pause_menu
}

# Create full system backup
backup_full_system() {
    print_header "Full System Backup"
    
    print_warning "This will create a complete backup of all websites and databases"
    if ! prompt_yes_no "Continue?"; then
        return
    fi
    
    local backup_dir="$BACKUP_ROOT/full"
    local backup_file="$backup_dir/full_system_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    print_info "Creating full system backup (this may take significant time)..."
    
    # Backup websites
    print_info "Backing up websites..."
    tar -czf "$backup_file" /root/websites 2>/dev/null || print_warning "Website backup failed"
    
    # Backup databases
    print_info "Backing up databases..."
    local db_cmd=$(get_db_command)
    $db_cmd -u root -proot --all-databases 2>/dev/null | gzip > "$backup_dir/databases_$(date +%Y%m%d_%H%M%S).sql.gz" || print_warning "Database backup failed"
    
    # Backup configurations
    print_info "Backing up configurations..."
    tar -czf "$backup_dir/configs_$(date +%Y%m%d_%H%M%S).tar.gz" \
        /etc/easypanel \
        /etc/nginx \
        /etc/apache2 \
        /etc/bind \
        /etc/postfix \
        /etc/dovecot 2>/dev/null || print_warning "Configuration backup failed"
    
    local size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
    print_success "Full system backup completed in $backup_dir ($size)"
    
    pause_menu
}

# List backups
list_backups() {
    print_header "Backup Files"
    
    if [ ! -d "$BACKUP_ROOT" ]; then
        print_info "No backups found"
        pause_menu
        return
    fi
    
    echo -e "${BOLD}Website Backups:${NC}"
    echo ""
    
    if [ "$(ls -A "$BACKUP_ROOT/websites" 2>/dev/null)" ]; then
        ls -lh "$BACKUP_ROOT/websites" | tail -n +2 | awk '{print "  " $9, "(" $5 ")"}'
    else
        echo "  No backups"
    fi
    
    echo ""
    echo -e "${BOLD}Database Backups:${NC}"
    echo ""
    
    if [ "$(ls -A "$BACKUP_ROOT/databases" 2>/dev/null)" ]; then
        ls -lh "$BACKUP_ROOT/databases" | tail -n +2 | awk '{print "  " $9, "(" $5 ")"}'
    else
        echo "  No backups"
    fi
    
    echo ""
    echo -e "${BOLD}Full Backups:${NC}"
    echo ""
    
    if [ "$(ls -A "$BACKUP_ROOT/full" 2>/dev/null)" ]; then
        ls -lh "$BACKUP_ROOT/full" | tail -n +2 | awk '{print "  " $9, "(" $5 ")"}'
    else
        echo "  No backups"
    fi
    
    echo ""
    
    local total_size=$(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)
    echo -e "${BOLD}Total Backup Size:${NC} $total_size"
    echo ""
    
    pause_menu
}

# Restore backup
restore_backup() {
    print_header "Restore Backup"
    
    local -a backup_files
    while IFS= read -r file; do
        backup_files+=("$file")
    done < <(find "$BACKUP_ROOT" -type f -name "*.tar.gz" -o -name "*.sql.gz" 2>/dev/null | sort -r)
    
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
                
                # Reload web server if applicable
                if prompt_yes_no "Reload web server?"; then
                    local web_server=$(get_config "WEB_SERVER")
                    restart_service "$web_server"
                fi
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

# Delete old backups
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

# Schedule automatic backups
schedule_backups() {
    print_header "Schedule Automatic Backups"
    
    echo "What would you like to backup automatically?"
    echo ""
    
    local backup_websites=0
    local backup_databases=0
    
    if prompt_yes_no "Backup websites daily?"; then
        backup_websites=1
    fi
    
    if prompt_yes_no "Backup databases daily?"; then
        backup_databases=1
    fi
    
    # Add to crontab
    if [ $backup_websites -eq 1 ]; then
        local website_hour=$(get_input "Hour for website backup (0-23)" "2")
        (crontab -u root -l 2>/dev/null; echo "0 $website_hour * * * tar -czf /root/backups/websites/backup_\$(date +\%Y\%m\%d).tar.gz /root/websites") | crontab -u root - 2>/dev/null
        print_success "Website backup scheduled for $website_hour:00"
    fi
    
    if [ $backup_databases -eq 1 ]; then
        local db_hour=$(get_input "Hour for database backup (0-23)" "3")
        local db_cmd=$(get_db_command)
        (crontab -u root -l 2>/dev/null; echo "0 $db_hour * * * $db_cmd -u root -proot --all-databases 2>/dev/null | gzip > /root/backups/databases/backup_\$(date +\%Y\%m\%d).sql.gz") | crontab -u root - 2>/dev/null
        print_success "Database backup scheduled for $db_hour:00"
    fi
    
    pause_menu
}

################################################################################
# Main Backup Menu
################################################################################

backup_menu() {
    init_backup
    
    while true; do
        print_header "Backup Management"
        
        echo -e "  ${CYAN}1)${NC} Backup Websites"
        echo -e "  ${CYAN}2)${NC} Backup Databases"
        echo -e "  ${CYAN}3)${NC} Full System Backup"
        echo -e "  ${CYAN}4)${NC} List Backups"
        echo -e "  ${CYAN}5)${NC} Restore Backup"
        echo -e "  ${CYAN}6)${NC} Schedule Automatic Backups"
        echo -e "  ${CYAN}7)${NC} Cleanup Old Backups"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-7]: " choice
        
        case "$choice" in
            1) backup_websites ;;
            2) backup_databases ;;
            3) backup_full_system ;;
            4) list_backups ;;
            5) restore_backup ;;
            6) schedule_backups ;;
            7) cleanup_old_backups ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}
