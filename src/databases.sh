#!/bin/bash

################################################################################
# EasyPanel - Database Management Script
# Manage MySQL/MariaDB databases and users
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

################################################################################
# Database Functions
################################################################################

# Check database connection
check_db_connection() {
    local db_type=$(get_config "DATABASE" "mariadb-server")
    
    if [ "$db_type" = "mysql-server" ]; then
        mysql -u root -proot -e "SELECT 1" >/dev/null 2>&1
    else
        mariadb -u root -proot -e "SELECT 1" >/dev/null 2>&1
    fi
    
    return $?
}

# Get database command
get_db_command() {
    local db_type=$(get_config "DATABASE" "mariadb-server")
    
    if [ "$db_type" = "mysql-server" ]; then
        echo "mysql"
    else
        echo "mariadb"
    fi
}

# List databases
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
            
            # Get database size
            local size=$($db_cmd -u root -proot -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE table_schema = '$db';" 2>/dev/null | tail -1)
            echo "      Size: ${size}MB"
            echo ""
        fi
    done
    
    pause_menu
}

# Create database
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
    
    # Validate database name
    if ! [[ $db_name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid database name (alphanumeric, underscore, hyphen only)"
        pause_menu
        return
    fi
    
    local db_cmd=$(get_db_command)
    local charset="utf8mb4"
    local collation="utf8mb4_general_ci"
    
    if $db_cmd -u root -proot -e "CREATE DATABASE \`$db_name\` CHARACTER SET $charset COLLATE $collation;" 2>/dev/null; then
        print_success "Database created: $db_name"
        
        # Ask to create user
        if prompt_yes_no "Create database user for this database?"; then
            local username=$(get_input "Database username" "${db_name}_user")
            local password
            read -sp "Database password: " password
            echo ""
            
            create_database_user "$username" "$db_name" "$password"
        fi
    else
        print_error "Failed to create database"
    fi
    
    pause_menu
}

# Create database user
create_database_user() {
    local username="$1"
    local database="$2"
    local password="$3"
    
    local db_cmd=$(get_db_command)
    
    if $db_cmd -u root -proot -e "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';" 2>/dev/null; then
        if $db_cmd -u root -proot -e "GRANT ALL PRIVILEGES ON \`$database\`.* TO '$username'@'localhost';" 2>/dev/null; then
            $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
            print_success "Database user created: $username"
        else
            print_error "Failed to grant privileges"
        fi
    else
        print_error "Failed to create database user"
    fi
}

# Add database user
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
    
    # Ask which databases to grant access to
    local db_cmd=$(get_db_command)
    
    echo ""
    echo "Select databases to grant access to:"
    echo ""
    
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
    
    local -a selected_dbs=()
    for i in "${!databases[@]}"; do
        if prompt_yes_no "Grant access to ${databases[$i]}?"; then
            selected_dbs+=("${databases[$i]}")
        fi
    done
    
    # Create user
    if $db_cmd -u root -proot -e "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';" 2>/dev/null; then
        # Grant privileges to selected databases
        for db in "${selected_dbs[@]}"; do
            $db_cmd -u root -proot -e "GRANT ALL PRIVILEGES ON \`$db\`.* TO '$username'@'localhost';" 2>/dev/null
        done
        
        $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
        print_success "Database user created: $username"
    else
        print_error "Failed to create user"
    fi
    
    pause_menu
}

# Edit database
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
    echo ""
    
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
    
    print_header "Edit Database: $database"
    
    echo -e "  ${CYAN}1)${NC} View database info"
    echo -e "  ${CYAN}2)${NC} View database users"
    echo -e "  ${CYAN}3)${NC} Backup database"
    echo -e "  ${CYAN}4)${NC} Optimize database"
    echo -e "  ${CYAN}5)${NC} Repair database"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1) show_database_info "$database" ;;
        2) show_database_users "$database" ;;
        3) backup_database "$database" ;;
        4) optimize_database "$database" ;;
        5) repair_database "$database" ;;
        0) return ;;
    esac
    
    pause_menu
}

# Show database information
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
    $db_cmd -u root -proot -e "SELECT TABLE_NAME, ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = '$database';" 2>/dev/null | tail -n +2 | while read line; do
        echo "  $line"
    done
    echo ""
}

# Show database users with access
show_database_users() {
    local database="$1"
    local db_cmd=$(get_db_command)
    
    print_header "Users with Access to $database"
    
    $db_cmd -u root -proot -e "SELECT user, host FROM mysql.user WHERE (Select COUNT(*) FROM information_schema.USER_PRIVILEGES WHERE GRANTEE = CONCAT(\"'\",user,\"'@'\",host,\"'\") AND TABLE_SCHEMA = '$database') > 0;" 2>/dev/null | tail -n +2 | while read user host; do
        echo "  $user@$host"
    done
}

# Backup database
backup_database() {
    local database="$1"
    local backup_dir="/root/backups/databases"
    local db_cmd=$(get_db_command)
    
    mkdir -p "$backup_dir"
    
    local backup_file="$backup_dir/${database}_$(date +%Y%m%d_%H%M%S).sql"
    
    print_info "Backing up database: $database..."
    
    if $db_cmd -u root -proot "$database" > "$backup_file" 2>/dev/null; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Database backup completed: $backup_file ($size)"
    else
        print_error "Database backup failed"
    fi
}

# Optimize database
optimize_database() {
    local database="$1"
    local db_cmd=$(get_db_command)
    
    print_info "Optimizing database: $database..."
    
    if $db_cmd -u root -proot -e "OPTIMIZE TABLE \`$database\`.*;" 2>/dev/null; then
        print_success "Database optimized"
    else
        print_error "Failed to optimize database"
    fi
}

# Repair database
repair_database() {
    local database="$1"
    local db_cmd=$(get_db_command)
    
    print_warning "This will attempt to repair corrupted tables in $database"
    
    if ! prompt_yes_no "Continue?"; then
        return
    fi
    
    print_info "Repairing database: $database..."
    
    if $db_cmd -u root -proot -e "REPAIR TABLE \`$database\`.*;" 2>/dev/null; then
        print_success "Database repaired"
    else
        print_error "Failed to repair database"
    fi
}

# Edit database user
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
    echo ""
    
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
    
    print_header "Edit User: $user"
    
    echo -e "  ${CYAN}1)${NC} Change password"
    echo -e "  ${CYAN}2)${NC} View privileges"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            local new_password
            read -sp "New password: " new_password
            echo ""
            
            if $db_cmd -u root -proot -e "ALTER USER '$username'@'$host' IDENTIFIED BY '$new_password';" 2>/dev/null; then
                $db_cmd -u root -proot -e "FLUSH PRIVILEGES;" 2>/dev/null
                print_success "Password changed for $user"
            else
                print_error "Failed to change password"
            fi
            ;;
        2)
            echo ""
            $db_cmd -u root -proot -e "SHOW GRANTS FOR '$username'@'$host';" 2>/dev/null | tail -n +2
            echo ""
            ;;
        0)
            return
            ;;
    esac
    
    pause_menu
}

# Delete database
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
    echo ""
    
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
    
    # Offer backup option
    if prompt_yes_no "Backup before deletion?"; then
        backup_database "$database"
    fi
    
    if prompt_yes_no "Delete database $database?"; then
        if $db_cmd -u root -proot -e "DROP DATABASE \`$database\`;" 2>/dev/null; then
            print_success "Database deleted: $database"
        else
            print_error "Failed to delete database"
        fi
    else
        print_info "Cancelled"
    fi
    
    pause_menu
}

# Delete database user
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
    echo ""
    
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
# Main Database Menu
################################################################################

databases_menu() {
    while true; do
        print_header "Database Management"
        
        echo -e "  ${CYAN}1)${NC} List Databases"
        echo -e "  ${CYAN}2)${NC} Create Database"
        echo -e "  ${CYAN}3)${NC} Edit Database"
        echo -e "  ${CYAN}4)${NC} Delete Database"
        echo -e "  ${CYAN}5)${NC} Add Database User"
        echo -e "  ${CYAN}6)${NC} Edit Database User"
        echo -e "  ${CYAN}7)${NC} Delete Database User"
        echo -e "  ${CYAN}8)${NC} Database Service Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-8]: " choice
        
        case "$choice" in
            1) list_databases ;;
            2) create_database ;;
            3) edit_database ;;
            4) delete_database ;;
            5) add_database_user ;;
            6) edit_database_user ;;
            7) delete_database_user ;;
            8)
                print_header "Database Service Status"
                local db_type=$(get_config "DATABASE" "mariadb-server")
                if service_running "$db_type"; then
                    echo -e "${GREEN}✓ $db_type${NC}: Running"
                else
                    echo -e "${RED}✗ $db_type${NC}: Stopped"
                fi
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
