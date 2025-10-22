#!/bin/bash

################################################################################
# EasyPanel - Mail Management Script
# Manage mail accounts, configure DKIM, SMTP Relay, Roundcube integration
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

MAIL_CONFIG_DIR="/etc/easypanel/mail"
MAIL_USERS_DIR="/home/mail"
DKIM_DIR="/etc/opendkim/keys"

################################################################################
# Mail Functions
################################################################################

# Initialize mail system
init_mail() {
    if ! service_running "postfix"; then
        print_error "Postfix is not running. Please install mail services first."
        return 1
    fi
    
    mkdir -p "$MAIL_CONFIG_DIR"
    mkdir -p "$MAIL_USERS_DIR"
    chmod 755 "$MAIL_USERS_DIR"
}

# List mail accounts
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
        
        # Check if DKIM is configured
        if [ -f "$DKIM_DIR/$account/default.private" ]; then
            echo -e "      DKIM: ${GREEN}Configured${NC}"
        fi
        
        # Check mailbox size
        local mailbox="$MAIL_USERS_DIR/$account/Maildir"
        if [ -d "$mailbox" ]; then
            local size=$(du -sh "$mailbox" 2>/dev/null | cut -f1)
            echo "      Size: $size"
        fi
        
        echo ""
    done
    
    pause_menu
}

# Add mail account
add_mail_account() {
    print_header "Add Mail Account"
    
    # Get email address
    while true; do
        local email=$(get_input "Enter email address" "user@example.com")
        
        if validate_email "$email"; then
            break
        fi
    done
    
    local username="${email%%@*}"
    local domain="${email##*@}"
    
    # Check if already exists
    if [ -d "$MAIL_USERS_DIR/$email" ]; then
        print_warning "Mail account already exists"
        pause_menu
        return
    fi
    
    # Get password
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
    
    # Ask for DKIM support
    local dkim_support="0"
    if prompt_yes_no "Enable DKIM support for this account?"; then
        dkim_support="1"
    fi
    
    # Ask for SMTP relay
    local smtp_relay="0"
    if prompt_yes_no "Enable SMTP relay for this account?"; then
        smtp_relay="1"
        # Get SMTP relay details
        local smtp_server=$(get_input "SMTP server hostname" "smtp.gmail.com")
        local smtp_port=$(get_input "SMTP port" "587")
        local smtp_user=$(get_input "SMTP username" "$email")
        local smtp_password
        read -sp "SMTP password: " smtp_password
        echo ""
    fi
    
    # Ask for Roundcube webmail
    local roundcube_enabled="0"
    if prompt_yes_no "Enable Roundcube webmail access?"; then
        roundcube_enabled="1"
    fi
    
    # Create mailbox
    print_info "Creating mailbox..."
    create_mailbox "$email" "$password"
    
    # Configure DKIM if requested
    if [ "$dkim_support" = "1" ]; then
        print_info "Configuring DKIM..."
        configure_dkim "$email"
    fi
    
    # Save mail account configuration
    save_mail_account_config "$email" "$dkim_support" "$smtp_relay" "$roundcube_enabled"
    
    print_success "Mail account created: $email"
    
    if [ "$dkim_support" = "1" ]; then
        echo ""
        print_info "DKIM Public Key (add to DNS TXT record):"
        get_dkim_public_key "$email"
    fi
    
    pause_menu
}

# Create mailbox directory structure
create_mailbox() {
    local email="$1"
    local password="$2"
    
    local mailbox_path="$MAIL_USERS_DIR/$email"
    
    # Create directory structure
    mkdir -p "$mailbox_path/Maildir"/{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Sent/"{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Drafts/"{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Trash/"{cur,new,tmp}
    mkdir -p "$mailbox_path/Maildir/.Spam/"{cur,new,tmp}
    
    # Set permissions
    chmod -R 755 "$mailbox_path"
    chmod -R 755 "$mailbox_path/Maildir"
    
    # Create Dovecot authentication entry
    local hash=$(echo -n "$password" | sha256sum | cut -d' ' -f1)
    echo "${email}:{SHA256-CRYPT}${hash}::${mailbox_path}:::" >> /etc/dovecot/passwd
    
    print_success "Mailbox created: $mailbox_path"
}

# Configure DKIM for mail account
configure_dkim() {
    local email="$1"
    local domain="${email##*@}"
    local selector="default"
    
    mkdir -p "$DKIM_DIR/$email"
    
    # Generate DKIM keypair
    print_info "Generating DKIM keypair (this may take a moment)..."
    
    opendkim-genkey -b 2048 -d "$domain" -D "$DKIM_DIR/$email" -s "$selector" 2>/dev/null || {
        print_warning "Failed to generate DKIM keypair with opendkim-genkey"
        # Try alternative method
        openssl genrsa -out "$DKIM_DIR/$email/$selector.private" 2048 2>/dev/null
        openssl rsa -in "$DKIM_DIR/$email/$selector.private" -pubout -out "$DKIM_DIR/$email/$selector.public" 2>/dev/null
    }
    
    # Set permissions
    chmod 600 "$DKIM_DIR/$email/$selector.private"
    chmod 644 "$DKIM_DIR/$email/$selector.txt"
    
    print_success "DKIM keypair generated"
}

# Get DKIM public key
get_dkim_public_key() {
    local email="$1"
    local selector="default"
    local key_file="$DKIM_DIR/$email/$selector.txt"
    
    if [ -f "$key_file" ]; then
        cat "$key_file"
    else
        print_warning "DKIM public key file not found"
    fi
}

# Edit mail account
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
    
    echo -e "  ${CYAN}1)${NC} Change password"
    echo -e "  ${CYAN}2)${NC} View DKIM key"
    echo -e "  ${CYAN}3)${NC} Enable/Disable DKIM"
    echo -e "  ${CYAN}4)${NC} View account info"
    echo -e "  ${CYAN}5)${NC} Manage Sieve filters"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            read -sp "New password: " new_password
            echo ""
            read -sp "Confirm password: " password_confirm
            echo ""
            
            if [ "$new_password" = "$password_confirm" ]; then
                update_mail_password "$email" "$new_password"
            else
                print_error "Passwords do not match"
            fi
            ;;
        2)
            if [ -f "$DKIM_DIR/$email/default.txt" ]; then
                print_header "DKIM Public Key for $email"
                cat "$DKIM_DIR/$email/default.txt"
            else
                print_info "DKIM not configured for this account"
            fi
            ;;
        3)
            if [ -f "$DKIM_DIR/$email/default.private" ]; then
                print_info "DKIM is enabled"
                if prompt_yes_no "Disable DKIM for this account?"; then
                    rm -f "$DKIM_DIR/$email"/*
                    print_success "DKIM disabled"
                fi
            else
                print_info "DKIM is not enabled"
                if prompt_yes_no "Enable DKIM for this account?"; then
                    configure_dkim "$email"
                    print_info "DKIM Public Key:"
                    get_dkim_public_key "$email"
                fi
            fi
            ;;
        4)
            show_mail_account_info "$email"
            ;;
        5)
            manage_sieve_filters "$email"
            ;;
        0)
            return
            ;;
    esac
    
    pause_menu
}

# Update mail account password
update_mail_password() {
    local email="$1"
    local password="$2"
    
    local hash=$(echo -n "$password" | sha256sum | cut -d' ' -f1)
    
    # Update in Dovecot passwd file
    sed -i "/^${email}:/d" /etc/dovecot/passwd
    echo "${email}:{SHA256-CRYPT}${hash}::${MAIL_USERS_DIR}/${email}:::" >> /etc/dovecot/passwd
    
    print_success "Password updated for $email"
}

# Show mail account information
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
    
    echo -e "${BOLD}DKIM Status:${NC}"
    if [ -f "$DKIM_DIR/$email/default.private" ]; then
        echo -e "  ${GREEN}✓ Enabled${NC}"
    else
        echo -e "  ${RED}✗ Disabled${NC}"
    fi
    echo ""
    
    pause_menu
}

# Manage Sieve mail filters
manage_sieve_filters() {
    local email="$1"
    local sieve_dir="$MAIL_USERS_DIR/$email/sieve"
    
    print_header "Sieve Filters for $email"
    
    mkdir -p "$sieve_dir"
    
    echo -e "  ${CYAN}1)${NC} View filters"
    echo -e "  ${CYAN}2)${NC} Create new filter"
    echo -e "  ${CYAN}3)${NC} Edit filters"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        1)
            if [ -f "$sieve_dir/default.sieve" ]; then
                echo ""
                cat "$sieve_dir/default.sieve"
            else
                print_info "No filters configured"
            fi
            ;;
        2)
            create_sieve_filter "$email" "$sieve_dir"
            ;;
        3)
            ${EDITOR:-nano} "$sieve_dir/default.sieve"
            ;;
        0)
            return
            ;;
    esac
    
    pause_menu
}

# Create Sieve filter interactively
create_sieve_filter() {
    local email="$1"
    local sieve_dir="$2"
    local sieve_file="$sieve_dir/default.sieve"
    
    print_header "Create Sieve Filter"
    
    echo ""
    echo "Filter examples:"
    echo "  1. Auto-reply to emails"
    echo "  2. Move emails to folder"
    echo "  3. Reject spam"
    echo "  4. Forward to another address"
    echo ""
    
    read -p "Enter filter number [1-4] or 0 to skip: " filter_type
    
    case "$filter_type" in
        1)
            local subject=$(get_input "Autoreply subject" "Out of Office")
            local message=$(get_input "Autoreply message" "I am currently out of the office")
            cat >> "$sieve_file" << EOF

require "vacation";
vacation
    :subject "$subject"
    :days 1
    "$message";
EOF
            ;;
        2)
            local from=$(get_input "From address pattern" "*")
            local folder=$(get_input "Destination folder" "Archive")
            cat >> "$sieve_file" << EOF

if address :contains "from" "$from" {
    fileinto "$folder";
}
EOF
            ;;
        3)
            cat >> "$sieve_file" << EOF

if header :contains "X-Spam-Score" ["***", "****", "*****"] {
    discard;
    stop;
}
EOF
            ;;
        4)
            local forward=$(get_input "Forward address")
            cat >> "$sieve_file" << EOF

redirect "$forward";
EOF
            ;;
        0)
            return
            ;;
    esac
    
    print_success "Sieve filter created"
}

# Delete mail account
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
    
    print_warning "This will permanently delete the mail account: $email"
    if ! prompt_yes_no "Continue?"; then
        print_info "Cancelled"
        pause_menu
        return
    fi
    
    # Remove mailbox
    rm -rf "$MAIL_USERS_DIR/$email"
    
    # Remove from Dovecot passwd
    sed -i "/^${email}:/d" /etc/dovecot/passwd
    
    # Remove DKIM keys
    rm -rf "$DKIM_DIR/$email"
    
    # Restart mail services
    restart_service "dovecot"
    restart_service "postfix"
    
    print_success "Mail account deleted: $email"
    pause_menu
}

# Save mail account configuration
save_mail_account_config() {
    local email="$1"
    local dkim_support="$2"
    local smtp_relay="$3"
    local roundcube="$4"
    
    local config_file="$MAIL_CONFIG_DIR/$email.conf"
    
    cat > "$config_file" << EOF
# Mail Account Configuration
EMAIL="$email"
DKIM_ENABLED="$dkim_support"
SMTP_RELAY="$smtp_relay"
ROUNDCUBE_ENABLED="$roundcube"
CREATED_DATE="$(date)"
EOF
    
    chmod 600 "$config_file"
}

################################################################################
# Main Mail Menu
################################################################################

mail_menu() {
    # Initialize mail system
    init_mail || {
        print_error "Mail system initialization failed"
        pause_menu
        return
    }
    
    while true; do
        print_header "Mail Management"
        
        echo -e "  ${CYAN}1)${NC} List Mail Accounts"
        echo -e "  ${CYAN}2)${NC} Add Mail Account"
        echo -e "  ${CYAN}3)${NC} Edit Mail Account"
        echo -e "  ${CYAN}4)${NC} Delete Mail Account"
        echo -e "  ${CYAN}5)${NC} Mail Service Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-5]: " choice
        
        case "$choice" in
            1) list_mail_accounts ;;
            2) add_mail_account ;;
            3) edit_mail_account ;;
            4) delete_mail_account ;;
            5)
                print_header "Mail Services Status"
                service_running "postfix" && echo -e "${GREEN}✓ Postfix${NC}: Running" || echo -e "${RED}✗ Postfix${NC}: Stopped"
                service_running "dovecot" && echo -e "${GREEN}✓ Dovecot${NC}: Running" || echo -e "${RED}✗ Dovecot${NC}: Stopped"
                service_running "clamav-daemon" && echo -e "${GREEN}✓ ClamAV${NC}: Running" || echo -e "${RED}✗ ClamAV${NC}: Stopped"
                service_running "spamassassin" && echo -e "${GREEN}✓ SpamAssassin${NC}: Running" || echo -e "${RED}✗ SpamAssassin${NC}: Stopped"
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
