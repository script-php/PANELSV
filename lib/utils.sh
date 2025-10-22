#!/bin/bash

################################################################################
# EasyPanel - Utility Functions Library
# Contains common functions for logging, user interaction, and system operations
################################################################################

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Panel configuration
PANEL_CONFIG_DIR="/etc/easypanel"
PANEL_CONFIG_FILE="$PANEL_CONFIG_DIR/config"
PANEL_LOG_FILE="/var/log/easypanel.log"
WEBSITES_ROOT="/root/websites"

################################################################################
# Output Functions
################################################################################

# Print a colored header
print_header() {
    clear
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║${NC} $1"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
    log_message "ERROR: $1"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "WARNING: $1"
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log_message "INFO: $1"
}

# Print a separator line
print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
}

################################################################################
# Logging Functions
################################################################################

# Log message to file
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$PANEL_LOG_FILE" 2>/dev/null
}

# Initialize log file
init_logging() {
    touch "$PANEL_LOG_FILE" 2>/dev/null
    chmod 644 "$PANEL_LOG_FILE" 2>/dev/null
}

################################################################################
# User Input Functions
################################################################################

# Simple yes/no prompt
prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$prompt (yes/no): " response
        case "$response" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                print_warning "Please answer yes or no."
                ;;
        esac
    done
}

# Prompt for selection from array
prompt_selection() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    
    while true; do
        clear
        print_header "$prompt"
        
        for ((i=0; i<${#options[@]}; i++)); do
            if [ $i -eq $selected ]; then
                echo -e "${CYAN}${BOLD}► ${options[$i]}${NC}"
            else
                echo "  ${options[$i]}"
            fi
        done
        
        echo ""
        print_info "Use UP/DOWN arrows, then press ENTER to select"
        
        # Note: This is a simplified version. For full arrow key support,
        # consider using 'fzf' or 'select' builtin
        read -p "Enter number (0-$((${#options[@]}-1))): " choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -lt ${#options[@]} ]; then
            selected=$choice
            return $selected
        else
            print_error "Invalid selection"
        fi
    done
}

# Simple menu selection
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

# Get user input
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

################################################################################
# System Check Functions
################################################################################

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed (Debian/Ubuntu)
package_installed() {
    dpkg -l | grep -q "^ii.*$1"
}

# Check if service is running
service_running() {
    systemctl is-active --quiet "$1"
}

# Check if service is enabled
service_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

################################################################################
# File Operation Functions
################################################################################

# Backup a file
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

# Create directory with proper permissions
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

# Remove directory safely
remove_directory() {
    local dir="$1"
    
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        print_success "Removed directory: $dir"
    fi
}

################################################################################
# Configuration Functions
################################################################################

# Initialize configuration
init_config() {
    create_directory "$PANEL_CONFIG_DIR" "root" "755"
    
    if [ ! -f "$PANEL_CONFIG_FILE" ]; then
        cat > "$PANEL_CONFIG_FILE" << 'EOF'
# EasyPanel Configuration
# Generated on first installation

# Web Server Choice (apache2 or nginx)
WEB_SERVER=""

# Database Choice (mysql or mariadb)
DATABASE=""

# Installed Services
SERVICES_INSTALLED=""

# System Information
PANEL_INSTALLED_DATE=""
PANEL_VERSION=""
EOF
        chmod 600 "$PANEL_CONFIG_FILE"
        print_success "Created configuration file: $PANEL_CONFIG_FILE"
    fi
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    if [ -f "$PANEL_CONFIG_FILE" ]; then
        # Remove existing key and add new one
        sed -i "/^${key}=/d" "$PANEL_CONFIG_FILE"
        echo "${key}=\"${value}\"" >> "$PANEL_CONFIG_FILE"
    fi
}

# Get configuration value
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
# Website/Domain Functions
################################################################################

# Create domain folder structure
create_domain_structure() {
    local domain="$1"
    local owner="${2:-www-data}"
    
    create_directory "$WEBSITES_ROOT/$domain/htdocs" "$owner" "755"
    create_directory "$WEBSITES_ROOT/$domain/config" "root" "755"
    create_directory "$WEBSITES_ROOT/$domain/logs" "$owner" "755"
    create_directory "$WEBSITES_ROOT/$domain/certificates" "root" "755"
    
    print_success "Created directory structure for domain: $domain"
}

# Remove domain folder structure
remove_domain_structure() {
    local domain="$1"
    
    if prompt_yes_no "Are you sure you want to delete all files for $domain?"; then
        remove_directory "$WEBSITES_ROOT/$domain"
    else
        print_info "Cancelled"
        return 1
    fi
}

# List all domains
list_domains() {
    if [ -d "$WEBSITES_ROOT" ]; then
        ls -d "$WEBSITES_ROOT"/*/ 2>/dev/null | xargs -n 1 basename
    fi
}

################################################################################
# Error Handling Functions
################################################################################

# Exit with error
die() {
    print_error "$1"
    exit 1
}

# Execute command with error handling
execute_command() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"
    
    if eval "$cmd"; then
        return 0
    else
        print_error "$error_msg"
        log_message "Command failed: $cmd"
        return 1
    fi
}

################################################################################
# Validation Functions
################################################################################

# Validate domain name
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

# Validate email
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

# Validate IP address
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

# Validate username
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
# Service Management Functions
################################################################################

# Start service
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

# Stop service
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

# Restart service
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

# Enable service
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

# Disable service
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
# Pause/Continue Functions
################################################################################

# Pause and wait for user input
pause_menu() {
    echo ""
    read -p "Press Enter to continue..."
}

copy_ssl_certificates_local() {
    local domain="$1"
    local cert_source="/etc/letsencrypt/live/$domain"
    local cert_dest="$WEBSITES_ROOT/$domain/certificates"
    
    if [ ! -d "$cert_source" ]; then
        print_warning "Source certificate directory not found: $cert_source"
        return 1
    fi
    
    # Copy all certificate files
    cp -r "$cert_source"/* "$cert_dest/" 2>/dev/null
    
    # Ensure proper permissions
    chmod 644 "$cert_dest"/*.pem 2>/dev/null
    chmod 600 "$cert_dest"/privkey.pem 2>/dev/null
    chown -R root:root "$cert_dest" 2>/dev/null
    
    print_success "Certificates copied to: $cert_dest"
}

# Export all functions for use in other scripts
export -f print_header print_success print_error print_warning print_info print_separator
export -f log_message init_logging prompt_yes_no print_menu get_input
export -f check_root command_exists package_installed service_running service_enabled
export -f backup_file create_directory remove_directory
export -f init_config set_config get_config
export -f create_domain_structure remove_domain_structure list_domains
export -f die execute_command
export -f validate_domain validate_email validate_ip validate_username
export -f start_service stop_service restart_service enable_service disable_service
export -f copy_ssl_certificates_local pause_menu
