#!/bin/bash

################################################################################
# EasyPanel - DNS Management Script
# Manage DNS records with BIND9 server
################################################################################

source "${SCRIPT_DIR}/../lib/utils.sh"

BIND_CONFIG_DIR="/etc/bind/easypanel"
BIND_ZONES_DIR="/var/lib/bind/easypanel"

################################################################################
# DNS Functions
################################################################################

# Initialize DNS directories
init_dns() {
    if ! command_exists "named"; then
        print_error "BIND9 is not installed. Please run installation first."
        return 1
    fi
    
    mkdir -p "$BIND_ZONES_DIR"
    chown -R bind:bind "$BIND_ZONES_DIR"
    chmod -R 755 "$BIND_ZONES_DIR"
}

# List DNS zones
list_dns_zones() {
    if [ ! -d "$BIND_ZONES_DIR" ]; then
        return
    fi
    
    ls -1 "$BIND_ZONES_DIR"/db.* 2>/dev/null | xargs -n 1 basename | sed 's/db\.//'
}

# Create DNS zone
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
    
    # Get nameserver IP
    local ns_ip=$(get_input "Enter nameserver IP" "8.8.8.8")
    if ! validate_ip "$ns_ip"; then
        return 1
    fi
    
    # Create zone file
    create_zone_file "$domain" "$ns_ip"
    
    # Add to BIND configuration
    add_zone_to_config "$domain"
    
    # Reload BIND
    restart_service "bind9"
    
    print_success "DNS zone created for $domain"
    pause_menu
}

# Create zone file
create_zone_file() {
    local domain="$1"
    local ns_ip="$2"
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

; Nameservers
@  IN  NS  ns1.$domain.
@  IN  NS  ns2.$domain.

; A records
@        IN  A      $ns_ip
www      IN  A      $ns_ip
ns1      IN  A      $ns_ip
ns2      IN  A      $ns_ip

; Mail records
@        IN  MX 10  mail.$domain.
mail     IN  A      $ns_ip

; CNAME records
# Add CNAMEs here as needed

; TXT records
@        IN  TXT    "v=spf1 mx ~all"

EOF
    
    chown bind:bind "$zone_file"
    chmod 640 "$zone_file"
    
    print_success "Created zone file: $zone_file"
}

# Add zone to BIND configuration
add_zone_to_config() {
    local domain="$1"
    local config_file="/etc/bind/named.conf.local"
    
    # Check if already added
    if grep -q "zone \"$domain\"" "$config_file"; then
        return 0
    fi
    
    cat >> "$config_file" << EOF

zone "$domain" {
    type master;
    file "$BIND_ZONES_DIR/db.$domain";
    allow-transfer { any; };
};

EOF
    
    print_success "Added zone to BIND configuration"
}

# List DNS records
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

# Add DNS record
add_dns_record() {
    print_header "Add DNS Record"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        if prompt_yes_no "Create a new zone?"; then
            create_dns_zone
        fi
        pause_menu
        return
    fi
    
    echo "Select zone:"
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
    
    echo ""
    echo "Select record type:"
    echo -e "  ${CYAN}1)${NC} A Record (IPv4)"
    echo -e "  ${CYAN}2)${NC} AAAA Record (IPv6)"
    echo -e "  ${CYAN}3)${NC} CNAME Record"
    echo -e "  ${CYAN}4)${NC} MX Record"
    echo -e "  ${CYAN}5)${NC} TXT Record"
    echo -e "  ${CYAN}6)${NC} NS Record"
    echo ""
    
    read -p "Select type [1-6]: " type_choice
    
    case "$type_choice" in
        1) add_a_record "$zone" "$zone_file" ;;
        2) add_aaaa_record "$zone" "$zone_file" ;;
        3) add_cname_record "$zone" "$zone_file" ;;
        4) add_mx_record "$zone" "$zone_file" ;;
        5) add_txt_record "$zone" "$zone_file" ;;
        6) add_ns_record "$zone" "$zone_file" ;;
        *)
            print_error "Invalid selection"
            ;;
    esac
    
    # Update serial
    update_zone_serial "$zone_file"
    
    # Reload BIND
    restart_service "bind9"
    
    print_success "Record added and BIND reloaded"
    pause_menu
}

# Add A record
add_a_record() {
    local zone="$1"
    local zone_file="$2"
    
    local name=$(get_input "Enter record name (@ for root, or subdomain)" "@")
    local ip=$(get_input "Enter IPv4 address")
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    echo "$name        IN  A      $ip" >> "$zone_file"
    print_success "Added A record: $name -> $ip"
}

# Add AAAA record
add_aaaa_record() {
    local zone="$1"
    local zone_file="$2"
    
    local name=$(get_input "Enter record name")
    local ipv6=$(get_input "Enter IPv6 address")
    
    echo "$name        IN  AAAA   $ipv6" >> "$zone_file"
    print_success "Added AAAA record: $name -> $ipv6"
}

# Add CNAME record
add_cname_record() {
    local zone="$1"
    local zone_file="$2"
    
    local name=$(get_input "Enter CNAME name")
    local target=$(get_input "Enter target domain")
    
    echo "$name        IN  CNAME  $target." >> "$zone_file"
    print_success "Added CNAME record: $name -> $target"
}

# Add MX record
add_mx_record() {
    local zone="$1"
    local zone_file="$2"
    
    local priority=$(get_input "Enter priority (10, 20, etc)" "10")
    local mail_server=$(get_input "Enter mail server hostname")
    
    echo "@        IN  MX $priority  $mail_server." >> "$zone_file"
    print_success "Added MX record: priority $priority -> $mail_server"
}

# Add TXT record
add_txt_record() {
    local zone="$1"
    local zone_file="$2"
    
    local name=$(get_input "Enter record name (@ for root)" "@")
    local value=$(get_input "Enter TXT value")
    
    echo "$name        IN  TXT    \"$value\"" >> "$zone_file"
    print_success "Added TXT record: $name -> $value"
}

# Add NS record
add_ns_record() {
    local zone="$1"
    local zone_file="$2"
    
    local ns_name=$(get_input "Enter nameserver hostname")
    local ns_ip=$(get_input "Enter nameserver IP")
    
    echo "$ns_name   IN  A      $ns_ip" >> "$zone_file"
    print_success "Added NS record: $ns_name -> $ns_ip"
}

# Update zone serial
update_zone_serial() {
    local zone_file="$1"
    local current_serial=$(grep "Serial" "$zone_file" | grep -oE '[0-9]{10}' | head -1)
    local new_serial=$(date +%Y%m%d01)
    
    if [ -n "$current_serial" ]; then
        sed -i "s/$current_serial/$new_serial/" "$zone_file"
    fi
}

# Edit DNS zone
edit_dns_zone() {
    print_header "Edit DNS Zone"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone to edit:"
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
    
    # Backup original file
    backup_file "$zone_file"
    
    # Edit file
    ${EDITOR:-nano} "$zone_file"
    
    # Check syntax
    if named-checkzone "$zone" "$zone_file" >/dev/null 2>&1; then
        print_success "Zone file syntax is valid"
        
        # Update serial
        update_zone_serial "$zone_file"
        
        # Reload BIND
        restart_service "bind9"
        
        print_success "Zone updated and BIND reloaded"
    else
        print_error "Zone file syntax error"
        if prompt_yes_no "Restore from backup?"; then
            local backup_file=$(ls -t "$zone_file.backup"* 2>/dev/null | head -1)
            if [ -n "$backup_file" ]; then
                cp "$backup_file" "$zone_file"
                print_success "Restored from backup"
            fi
        fi
    fi
    
    pause_menu
}

# Delete DNS record
delete_dns_record() {
    print_header "Delete DNS Record"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone:"
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
    
    # Show current records (excluding SOA and NS)
    print_header "Current DNS Records (excluding SOA/NS)"
    echo ""
    grep -v "SOA\|NS" "$zone_file" | grep -v "^;" | grep -v "^\s*$" | nl
    echo ""
    
    read -p "Enter line number to delete: " line_num
    
    if [[ ! $line_num =~ ^[0-9]+$ ]]; then
        print_error "Invalid line number"
        pause_menu
        return
    fi
    
    # Get the actual line (considering filtered output)
    local line_to_delete=$(grep -v "SOA\|NS" "$zone_file" | grep -v "^;" | grep -v "^\s*$" | sed -n "${line_num}p")
    
    if [ -n "$line_to_delete" ]; then
        if prompt_yes_no "Delete: $line_to_delete ?"; then
            backup_file "$zone_file"
            grep -v "$line_to_delete" "$zone_file" > "$zone_file.tmp"
            mv "$zone_file.tmp" "$zone_file"
            
            # Update serial
            update_zone_serial "$zone_file"
            
            # Reload BIND
            restart_service "bind9"
            
            print_success "Record deleted and BIND reloaded"
        fi
    else
        print_error "Record not found"
    fi
    
    pause_menu
}

# Delete DNS zone
delete_dns_zone() {
    print_header "Delete DNS Zone"
    
    local zones=($(list_dns_zones))
    
    if [ ${#zones[@]} -eq 0 ]; then
        print_info "No DNS zones configured"
        pause_menu
        return
    fi
    
    echo "Select zone to delete:"
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
    
    if prompt_yes_no "Delete DNS zone for $zone?"; then
        # Remove zone file
        rm -f "$BIND_ZONES_DIR/db.$zone"
        
        # Remove from BIND config
        sed -i "/^zone \"$zone\"/,/^}/d" "/etc/bind/named.conf.local"
        
        # Reload BIND
        restart_service "bind9"
        
        print_success "DNS zone deleted for $zone"
    fi
    
    pause_menu
}

# Check DNS zone status
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

################################################################################
# Main DNS Menu
################################################################################

dns_menu() {
    # Initialize DNS
    init_dns || {
        print_error "DNS initialization failed"
        pause_menu
        return
    }
    
    while true; do
        print_header "DNS Management"
        
        echo -e "  ${CYAN}1)${NC} List DNS Records"
        echo -e "  ${CYAN}2)${NC} Create DNS Zone"
        echo -e "  ${CYAN}3)${NC} Add DNS Record"
        echo -e "  ${CYAN}4)${NC} Edit DNS Zone"
        echo -e "  ${CYAN}5)${NC} Delete DNS Record"
        echo -e "  ${CYAN}6)${NC} Delete DNS Zone"
        echo -e "  ${CYAN}7)${NC} DNS Status"
        echo -e "  ${CYAN}0)${NC} Back"
        
        print_separator
        read -p "Select option [0-7]: " choice
        
        case "$choice" in
            1) list_dns_records ;;
            2) create_dns_zone ;;
            3) add_dns_record ;;
            4) edit_dns_zone ;;
            5) delete_dns_record ;;
            6) delete_dns_zone ;;
            7) check_dns_status ;;
            0) return ;;
            *)
                print_error "Invalid option"
                pause_menu
                ;;
        esac
    done
}
