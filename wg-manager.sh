#!/bin/bash

# -----------------------------------------------------------------------------
# WireGuard Manager Script
# Cross-platform for macOS and Linux
# Based on https://github.com/isimtekin/wireguard
# -----------------------------------------------------------------------------
#
# Copyright (c) 2025
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# -----------------------------------------------------------------------------

# Script version
VERSION="1.0.3"

# ---------- Color Definitions ----------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[0;33m'
readonly NC='\033[0m' # No Color

# ---------- Configuration Defaults ----------
readonly DEFAULT_PORT=51820
readonly DEFAULT_DNS="1.1.1.1"
readonly DEFAULT_SUBNET_BASE="10.0.0"
readonly DEFAULT_HOST_IP=1
readonly DEFAULT_WG_INTERFACE="wg0"

# ---------- Helper Functions ----------
function log_info() {
  echo -e "${GREEN}$1${NC}"
}

function log_warning() {
  echo -e "${ORANGE}$1${NC}"
}

function log_error() {
  echo -e "${RED}$1${NC}"
  exit 1
}

function show_usage() {
  echo -e "${ORANGE}WireGuard Manager Script${NC} ${GREEN}v${VERSION}${NC}"
  echo -e "\n${GREEN}Usage:${NC} $(basename $0) COMMAND"
  echo -e "\n${GREEN}Commands:${NC}"
  echo -e "  ${ORANGE}install${NC}             Install WireGuard on the current system"
  echo -e "  ${ORANGE}config${NC}              Create WireGuard server configuration"
  echo -e "  ${ORANGE}add-client${NC}          Add a new client to WireGuard server"
  echo -e "  ${ORANGE}transfer-conf${NC}       Transfer a client config from server to destination"
  echo -e "  ${ORANGE}download-conf${NC}       Download a client config from server to local machine"
  echo -e "  ${ORANGE}list-clients${NC}        List all existing WireGuard clients"
  echo -e "  ${ORANGE}status${NC}              Show current WireGuard status and configuration summary"
  echo -e "  ${ORANGE}activate${NC}            Start the WireGuard server"
  echo -e "  ${ORANGE}deactivate${NC}          Stop the WireGuard server"
  echo -e "  ${ORANGE}restart${NC}             Restart the WireGuard server"
  echo -e "  ${ORANGE}upgrade${NC}             Check for updates and upgrade to the latest version"
  echo -e "  ${ORANGE}help${NC}                Show this help message"
  echo -e "\n${GREEN}Examples:${NC}"
  echo -e "  $(basename $0) install                       # Install WireGuard"
  echo -e "  $(basename $0) config                        # Set up server configuration"
  echo -e "  $(basename $0) add-client                    # Add a new client"
  echo -e "  $(basename $0) status                        # Show server status and configuration"
  echo -e "  $(basename $0) restart                       # Restart WireGuard server"
  echo -e "  $(basename $0) upgrade                       # Update to the latest version"
}

function check_root() {
  if [ "${EUID}" -ne 0 ]; then
    log_error "This script must be run as root"
  fi
}

function detect_os() {
  if [ "$(uname)" == "Darwin" ]; then
    echo "macos"
    return
  elif [ -e /etc/os-release ]; then
    source /etc/os-release
    echo ${ID}
    return
  else
    log_error "Unable to detect OS. Exiting."
  fi
}

function get_config_dir() {
  local os=$(detect_os)
  if [ "$os" == "macos" ]; then
    echo "/usr/local/etc/wireguard"
  else
    echo "/etc/wireguard"
  fi
}

function get_public_ip() {
  local os=$(detect_os)
  local ip

  if [ "$os" == "macos" ]; then
    # Try to get public IP on macOS
    ip=$(ifconfig en0 2>/dev/null | grep inet | grep -v inet6 | awk '{print $2}')
    if [ -z "$ip" ]; then
      ip=$(curl -s https://api.ipify.org)
    fi
  else
    # Linux IP detection
    ip=$(ip -4 addr | grep inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
    if [ -z "$ip" ]; then
      ip=$(curl -s https://api.ipify.org)
    fi
  fi

  echo "$ip"
}

function get_network_interface() {
  local os=$(detect_os)
  local interface

  if [ "$os" == "macos" ]; then
    # Get primary interface on macOS
    interface=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -z "$interface" ]; then
      interface="en0"
    fi
  else
    # Get primary interface on Linux
    interface=$(ip route get 1 | awk '{print $5; exit}')
  fi

  echo "$interface"
}

function generate_random_number() {
  local min=$1
  local max=$2
  local os=$(detect_os)

  if [ "$os" == "macos" ]; then
    echo $(jot -r 1 $min $max)
  else
    echo $(shuf -i $min-$max -n 1)
  fi
}

function check_server_config() {
  local config_dir=$(get_config_dir)
  local config_file="${config_dir}/${DEFAULT_WG_INTERFACE}-server.conf"

  if [ ! -f "$config_file" ]; then
    log_error "Server configuration not found. Please run '$(basename $0) config' first."
  fi

  # Read variables from server config if they exist
  if [ -f "${config_dir}/server_vars" ]; then
    source "${config_dir}/server_vars"
  fi
}

# ---------- Core Functions ----------
function install_wireguard() {
  local os=$(detect_os)
  log_info "Installing WireGuard for ${os}"

  case $os in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        log_error "Homebrew is not installed. Please install Homebrew first: https://brew.sh"
      fi
      brew install wireguard-tools
      ;;
    ubuntu|debian)
      apt update && apt install -y wireguard
      ;;
    fedora)
      dnf install -y wireguard-tools
      ;;
    centos|rocky|almalinux)
      yum install -y epel-release
      yum install -y wireguard-tools
      ;;
    arch)
      pacman -S --noconfirm wireguard-tools
      ;;
    alpine)
      apk update && apk add wireguard-tools
      ;;
    *)
      log_error "OS $os not supported."
      ;;
  esac

  log_info "WireGuard installed successfully."
}

function create_server_config() {
  local os=$(detect_os)
  local config_dir=$(get_config_dir)

  log_info "Creating WireGuard server configuration..."

  # Auto-detect server details
  local guess_ip=$(get_public_ip)
  local guess_iface=$(get_network_interface)

  # Get user input with defaults
  read -rp "Public IP (auto-detected: $guess_ip): " SERVER_PUB_IP
  SERVER_PUB_IP=${SERVER_PUB_IP:-$guess_ip}

  read -rp "Public Network Interface (auto-detected: $guess_iface): " SERVER_PUB_NIC
  SERVER_PUB_NIC=${SERVER_PUB_NIC:-$guess_iface}

  read -rp "WireGuard Interface Name [$DEFAULT_WG_INTERFACE]: " SERVER_WG_NIC
  SERVER_WG_NIC=${SERVER_WG_NIC:-$DEFAULT_WG_INTERFACE}

  read -rp "Private Subnet Base (e.g. $DEFAULT_SUBNET_BASE): " PRIVATE_SUBNET_BASE
  PRIVATE_SUBNET_BASE=${PRIVATE_SUBNET_BASE:-$DEFAULT_SUBNET_BASE}

  read -rp "Server Host IP (last octet, e.g. $DEFAULT_HOST_IP): " SERVER_HOST_IP
  SERVER_HOST_IP=${SERVER_HOST_IP:-$DEFAULT_HOST_IP}

  read -rp "UDP Port [$DEFAULT_PORT]: " SERVER_PORT
  SERVER_PORT=${SERVER_PORT:-$DEFAULT_PORT}

  read -rp "Client DNS [$DEFAULT_DNS]: " CLIENT_DNS
  CLIENT_DNS=${CLIENT_DNS:-$DEFAULT_DNS}

  # Setup server configuration
  SERVER_WG_IP="$PRIVATE_SUBNET_BASE.$SERVER_HOST_IP/24"
  ALLOWED_IPS="$PRIVATE_SUBNET_BASE.0/24"

  # Create config directory
  mkdir -p "$config_dir"
  chmod 700 "$config_dir"

  # Generate keys
  local private_key=$(wg genkey)
  local public_key=$(echo "$private_key" | wg pubkey)

  echo "$private_key" > "${config_dir}/privatekey"
  echo "$public_key" > "${config_dir}/publickey"
  chmod 600 "${config_dir}/privatekey"

  # Create server config file
  local config_file="${config_dir}/${SERVER_WG_NIC}-server.conf"

  # Create different PostUp/PostDown rules based on OS
  if [ "$os" == "macos" ]; then
    cat > "$config_file" <<EOL
[Interface]
Address = $SERVER_WG_IP
ListenPort = $SERVER_PORT
PrivateKey = $private_key

# macOS specific routing rules
PostUp = /usr/sbin/sysctl -w net.inet.ip.forwarding=1
PostDown = /usr/sbin/sysctl -w net.inet.ip.forwarding=0
EOL
  else
    # Linux configuration
    cat > "$config_file" <<EOL
[Interface]
Address = $SERVER_WG_IP
ListenPort = $SERVER_PORT
PrivateKey = $private_key

SaveConfig = true
PostUp   = iptables -A FORWARD -i $SERVER_WG_NIC -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
PostDown = iptables -D FORWARD -i $SERVER_WG_NIC -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
EOL
  fi

  log_info "Server config created at: $config_file"

  # Create a variables file for future reference
  cat > "${config_dir}/server_vars" <<EOL
SERVER_PUB_IP=$SERVER_PUB_IP
SERVER_PUB_NIC=$SERVER_PUB_NIC
SERVER_WG_NIC=$SERVER_WG_NIC
PRIVATE_SUBNET_BASE=$PRIVATE_SUBNET_BASE
SERVER_PORT=$SERVER_PORT
CLIENT_DNS=$CLIENT_DNS
ALLOWED_IPS=$ALLOWED_IPS
EOL

  chmod 600 "${config_dir}/server_vars"
}

function add_client() {
  local os=$(detect_os)
  local config_dir=$(get_config_dir)

  log_info "Creating new WireGuard client configuration..."

  # Source server variables if they exist
  if [ -f "${config_dir}/server_vars" ]; then
    source "${config_dir}/server_vars"
  fi

  # Find WireGuard server config file
  local server_confs=( $(ls ${config_dir}/*-server.conf 2>/dev/null) )
  if [ ${#server_confs[@]} -eq 0 ]; then
    log_error "❌ No WireGuard server configuration found. Run '$(basename $0) config' first."
  fi

  # Use the first server config found if SERVER_WG_NIC is not set
  local server_config_file="${server_confs[0]}"
  if [ -z "$SERVER_WG_NIC" ]; then
    SERVER_WG_NIC=$(basename "${server_config_file}" -server.conf)
    log_info "📄 Using detected interface: ${SERVER_WG_NIC}"
  fi

  # Read actual subnet from config file if PRIVATE_SUBNET_BASE is not set
  if [ -z "$PRIVATE_SUBNET_BASE" ] || [ -z "$SERVER_HOST_IP" ]; then
    if [ -f "$server_config_file" ]; then
      # Extract IP from the config file (format like: Address = 10.100.0.1/24)
      local full_address=$(grep "Address" "$server_config_file" | cut -d '=' -f2 | tr -d ' ')
      if [ -n "$full_address" ]; then
        # Parse IP like 10.100.0.1/24 to extract base (10.100.0) and host IP (1)
        local ip_part=$(echo "$full_address" | cut -d'/' -f1)
        SERVER_HOST_IP=$(echo "$ip_part" | rev | cut -d'.' -f1 | rev)
        PRIVATE_SUBNET_BASE=$(echo "$ip_part" | rev | cut -d'.' -f2- | rev)
        log_info "📄 Read subnet from config: ${PRIVATE_SUBNET_BASE}.0/24"
      fi
    fi
  fi

  # If we still don't have a subnet base, use default
  if [ -z "$PRIVATE_SUBNET_BASE" ]; then
    PRIVATE_SUBNET_BASE="$DEFAULT_SUBNET_BASE"
    log_warning "⚠️ Using default subnet: ${PRIVATE_SUBNET_BASE}.0/24"
  fi

  # Read other server configuration if needed
  if [ -z "$SERVER_PORT" ] && [ -f "$server_config_file" ]; then
    SERVER_PORT=$(grep "ListenPort" "$server_config_file" | cut -d '=' -f2 | tr -d ' ')
  fi

  if [ -z "$SERVER_PORT" ]; then
    SERVER_PORT="$DEFAULT_PORT"
  fi

  if [ -z "$CLIENT_DNS" ]; then
    CLIENT_DNS="$DEFAULT_DNS"
  fi

  # Get the server public key
  local server_public_key=""
  if [ -f "${config_dir}/publickey" ]; then
    server_public_key=$(cat "${config_dir}/publickey")
  else
    log_error "❌ Server public key not found. Please run '$(basename $0) config' first."
  fi

  # Get the server public IP if not already set
  if [ -z "$SERVER_PUB_IP" ]; then
    SERVER_PUB_IP=$(get_public_ip)
    log_info "📡 Detected server public IP: ${SERVER_PUB_IP}"
  fi

  # Get client name
  read -rp "Client name: " CLIENT_NAME

  if [ -z "$CLIENT_NAME" ]; then
    log_error "Client name cannot be empty."
  fi

  if [ -f "${config_dir}/${CLIENT_NAME}.conf" ]; then
    read -rp "Client config already exists. Overwrite? (y/N): " OVERWRITE
    if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
      log_warning "Client creation cancelled."
      return
    fi
  fi

  # Generate client keys
  local client_private_key=$(wg genkey)
  local client_public_key=$(echo "$client_private_key" | wg pubkey)
  local client_preshared_key=$(wg genpsk)

  # Generate a random IP for the client
  local client_last_octet=$(generate_random_number 2 254)
  local client_ipv4="$PRIVATE_SUBNET_BASE.$client_last_octet/32"

  # Find ALLOWED_IPS setting
  if [ -z "$ALLOWED_IPS" ]; then
    ALLOWED_IPS="$PRIVATE_SUBNET_BASE.0/24"
  fi

  # Create client config file
  local client_config_file="${config_dir}/${CLIENT_NAME}.conf"

  cat > "$client_config_file" <<EOL
[Interface]
PrivateKey = $client_private_key
Address = $client_ipv4
DNS = $CLIENT_DNS

[Peer]
PublicKey = $server_public_key
PresharedKey = $client_preshared_key
Endpoint = $SERVER_PUB_IP:$SERVER_PORT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
EOL

  log_info "Client config created at: $client_config_file"
  log_info "Using subnet: ${PRIVATE_SUBNET_BASE}.0/24"
  log_info "Client IP assigned: $client_ipv4"

  # Add client to server config
  {
    echo ""
    echo "### Client $CLIENT_NAME"
    echo "[Peer]"
    echo "PublicKey = $client_public_key"
    echo "PresharedKey = $client_preshared_key"
    echo "AllowedIPs = $client_ipv4"
  } >> "${config_dir}/${SERVER_WG_NIC}-server.conf"

  # Create QR code if qrencode is available
  if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ansiutf8 < "$client_config_file"
    log_info "Scan the QR code with your mobile device to import the configuration."
  else
    log_info "Install qrencode to generate QR codes for easy mobile import."
  fi

  # Zip the config if zip is available
  if command -v zip >/dev/null 2>&1; then
    local zip_file="${config_dir}/${CLIENT_NAME}.zip"
    zip -j "$zip_file" "$client_config_file" >/dev/null
    log_info "Client config zipped to: $zip_file"

    log_info "\nYou can download the client config with the following command from your local machine:\n"
    log_warning "scp root@$SERVER_PUB_IP:$zip_file ./"
  else
    log_info "\nYou can download the client config with the following command from your local machine:\n"
    log_warning "scp root@$SERVER_PUB_IP:$client_config_file ./"
  fi

  # Ask if user wants to restart the server
  read -rp "Do you want to restart the WireGuard server to apply changes? (y/N): " RESTART
  if [[ $RESTART =~ ^[Yy]$ ]]; then
    restart_server
  else
    log_warning "Server not restarted. New client will not be able to connect until server is restarted."
    log_warning "Run '$(basename $0) restart' to apply changes."
  fi
}

function transfer_config() {
  local config_dir=$(get_config_dir)

  log_info "Transfer client configuration between servers..."

  read -rp "Server IP: " SERVER_IP
  read -rp "Destination IP: " DEST_IP
  read -rp "Client name: " CLIENT_NAME

  if [ -z "$SERVER_IP" ] || [ -z "$DEST_IP" ] || [ -z "$CLIENT_NAME" ]; then
    log_error "All fields are required."
  fi

  local conf_file="${CLIENT_NAME}.conf"
  local remote_config_dir=$(get_config_dir)

  log_info "Fetching $conf_file from $SERVER_IP..."
  scp "root@$SERVER_IP:${remote_config_dir}/$conf_file" ./ || log_error "Failed to fetch config from server."

  log_info "Uploading $conf_file to $DEST_IP:${remote_config_dir}/"
  ssh "root@$DEST_IP" "mkdir -p ${remote_config_dir}" || log_error "Failed to create directory on destination."
  scp "./$conf_file" "root@$DEST_IP:${remote_config_dir}/" || log_error "Failed to upload config to destination."

  log_info "Done! $conf_file transferred from $SERVER_IP to $DEST_IP."
  log_info "\nTo activate the client on $DEST_IP, SSH into it and run:"
  log_warning "sudo wg-quick up $CLIENT_NAME"

  # Clean up local file
  rm -f "$conf_file"
}

function download_config() {
  local config_dir=$(get_config_dir)

  log_info "Downloading client configuration..."

  read -rp "Server IP: " SERVER_IP
  read -rp "Client name: " CLIENT_NAME

  if [ -z "$SERVER_IP" ] || [ -z "$CLIENT_NAME" ]; then
    log_error "Server IP and client name are required."
  fi

  local conf_file="${CLIENT_NAME}.conf"
  local remote_config_dir=$(get_config_dir)

  log_info "Downloading $conf_file from $SERVER_IP..."
  scp "root@$SERVER_IP:${remote_config_dir}/$conf_file" ./ || log_error "Failed to download config file."
  log_info "Download complete. File saved as ./$conf_file"
}

function list_clients() {
  local config_dir=$(get_config_dir)

  log_info "Listing existing WireGuard clients..."

  if [ ! -d "$config_dir" ]; then
    log_error "WireGuard configuration directory not found."
  fi

  if ! ls ${config_dir}/*-server.conf >/dev/null 2>&1; then
    log_warning "No server configuration found."
    return
  fi

  # Use grep with cross-platform compatibility
  local client_count=$(grep -E '^### Client' ${config_dir}/*-server.conf 2>/dev/null | wc -l | tr -d ' ')

  if [ "$client_count" -eq 0 ]; then
    log_warning "No clients found."
    return
  fi

  log_info "Found $client_count client(s):"

  # This should work on both macOS and Linux
  grep -E '^### Client' ${config_dir}/*-server.conf 2>/dev/null | sed 's/.*Client //' | cat -n
}

function activate_server() {
  local os=$(detect_os)
  local config_dir=$(get_config_dir)

  # Source server variables
  if [ -f "${config_dir}/server_vars" ]; then
    source "${config_dir}/server_vars"
  else
    check_server_config
  fi

  log_info "Activating WireGuard server..."

  local config_file="${config_dir}/${SERVER_WG_NIC}-server.conf"

  if [ ! -f "$config_file" ]; then
    log_error "Server configuration not found."
  fi

  # OS-specific activation
  if [ "$os" == "macos" ]; then
    # macOS WireGuard activation
    log_info "Enabling IP forwarding on macOS..."
    sudo sysctl -w net.inet.ip.forwarding=1

    log_info "Starting WireGuard with wg-quick..."
    sudo wg-quick up "$config_file"

    log_info "To make IP forwarding persistent across reboots, add 'net.inet.ip.forwarding=1' to /etc/sysctl.conf"
  else
    # Linux WireGuard activation
    log_info "Enabling IP forwarding on Linux..."
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Make IP forwarding persistent
    if [ -f /etc/sysctl.conf ]; then
      if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
      fi
    fi

    # Start and enable WireGuard
    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable wg-quick@${SERVER_WG_NIC}
      systemctl start wg-quick@${SERVER_WG_NIC}
      systemctl status wg-quick@${SERVER_WG_NIC} --no-pager
    else
      # For non-systemd systems
      wg-quick up ${SERVER_WG_NIC}
    fi
  fi

  log_info "WireGuard server activated successfully."
  log_info "Interface: ${SERVER_WG_NIC}"
  log_info "To check status: wg show"
}

# ---------- Main Script ----------
function show_status() {
  local os=$(detect_os)
  local config_dir=$(get_config_dir)

  log_info "🔎 WireGuard Status Summary"
  echo -e "${GREEN}───────────────────────────────────────────────────${NC}"

  # Check if WireGuard is installed
  if ! command -v wg &> /dev/null; then
    log_warning "❌ WireGuard is not installed. Run '$(basename $0) install' first."
    return 1
  fi

  # Find WireGuard interface and server config
  local server_confs=( $(ls ${config_dir}/*-server.conf 2>/dev/null) )
  if [ ${#server_confs[@]} -eq 0 ]; then
    log_warning "❌ No WireGuard server configuration found. Run '$(basename $0) config' first."
    return 1
  fi

  # Use the first server config found if not set
  local server_config_file="${server_confs[0]}"
  if [ -z "$SERVER_WG_NIC" ]; then
    SERVER_WG_NIC=$(basename "${server_config_file}" -server.conf)
  fi

  # Source server variables if they exist
  if [ -f "${config_dir}/server_vars" ]; then
    source "${config_dir}/server_vars"
    echo -e "${GREEN}✅ Configuration found${NC}"
  else
    log_warning "⚠️  Using detected configuration: ${SERVER_WG_NIC}"
  fi

  # Read actual subnet from config file if not in server_vars
  if [ -z "$PRIVATE_SUBNET_BASE" ] || [ -z "$SERVER_HOST_IP" ]; then
    if [ -f "$server_config_file" ]; then
      # Extract IP from the config file (format like: Address = 10.100.0.1/24)
      local full_address=$(grep "Address" "$server_config_file" | cut -d '=' -f2 | tr -d ' ')
      if [ -n "$full_address" ]; then
        # Parse IP like 10.100.0.1/24 to extract base (10.100.0) and host IP (1)
        local ip_part=$(echo "$full_address" | cut -d'/' -f1)
        SERVER_HOST_IP=$(echo "$ip_part" | rev | cut -d'.' -f1 | rev)
        PRIVATE_SUBNET_BASE=$(echo "$ip_part" | rev | cut -d'.' -f2- | rev)
        log_info "📄 Read subnet from config: ${PRIVATE_SUBNET_BASE}.0/24"
      fi
    fi
  fi

  # Check if the interface is running
  if ip link show "$SERVER_WG_NIC" &>/dev/null || ifconfig "$SERVER_WG_NIC" &>/dev/null 2>&1; then
    echo -e "${GREEN}✅ Interface status: ${ORANGE}ACTIVE${NC}"
  else
    echo -e "${ORANGE}⚠️  Interface status: INACTIVE${NC}"
    echo -e "${ORANGE}   Run '$(basename $0) activate' to start the server${NC}"
  fi

  echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
  echo -e "${GREEN}📊 Server Configuration:${NC}"

  # Get current public IP
  local current_ip=$(get_public_ip)
  echo -e "   📡 Original Public IP : ${ORANGE}${SERVER_PUB_IP:-Unknown}${NC}"
  echo -e "   📡 Current Public IP  : ${ORANGE}${current_ip}${NC}"

  if [[ "$current_ip" != "$SERVER_PUB_IP" && -n "$SERVER_PUB_IP" ]]; then
    echo -e "   ${ORANGE}⚠️  Public IP has changed! You may need to update client configs.${NC}"
  fi

  # Get interface info
  echo -e "   🌐 WireGuard Interface: ${ORANGE}${SERVER_WG_NIC:-wg0}${NC}"
  echo -e "   🔌 Network Interface  : ${ORANGE}${SERVER_PUB_NIC:-Unknown}${NC}"

  # Get port from config file if not set
  if [ -z "$SERVER_PORT" ] && [ -f "$server_config_file" ]; then
    SERVER_PORT=$(grep "ListenPort" "$server_config_file" | cut -d '=' -f2 | tr -d ' ')
  fi
  echo -e "   🔢 UDP Port          : ${ORANGE}${SERVER_PORT:-51820}${NC}"

  # Network details - Use what we found in the config file
  echo -e "   🔢 Private Subnet    : ${ORANGE}${PRIVATE_SUBNET_BASE:-10.0.0}.0/24${NC}"
  echo -e "   🔢 Server Host IP    : ${ORANGE}${PRIVATE_SUBNET_BASE:-10.0.0}.${SERVER_HOST_IP:-1}/24${NC}"

  # Get DNS from config file if not set
  if [ -z "$CLIENT_DNS" ]; then
    local client_conf_files=( $(ls "${config_dir}/"*.conf 2>/dev/null) )
    for conf_file in "${client_conf_files[@]}"; do
      if [ -f "$conf_file" ] && grep -q "DNS" "$conf_file" 2>/dev/null; then
        CLIENT_DNS=$(grep "DNS" "$conf_file" | head -1 | cut -d '=' -f2 | tr -d ' ')
        break
      fi
    done
  fi
  echo -e "   🔠 Client DNS Server : ${ORANGE}${CLIENT_DNS:-1.1.1.1}${NC}"

  # Get clients count
  local client_count=$(grep -E '^### Client' "${config_dir}/${SERVER_WG_NIC}-server.conf" 2>/dev/null | wc -l | tr -d ' ')
  echo -e "   👥 Client Count      : ${ORANGE}${client_count:-0}${NC}"

  # Show detailed interface info if running
  echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
  if wg show "$SERVER_WG_NIC" &>/dev/null; then
    echo -e "${GREEN}📈 Active Interface Details:${NC}"
    wg show "$SERVER_WG_NIC"
  else
    echo -e "${ORANGE}⚠️  Interface not active. No detailed status available.${NC}"
  fi

  # Show traffic statistics if available
  if command -v vnstat &>/dev/null && vnstat -i "$SERVER_WG_NIC" &>/dev/null; then
    echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}📶 Traffic Statistics:${NC}"
    vnstat -i "$SERVER_WG_NIC" --oneline
  fi

  echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
}

function deactivate_server() {
  local os=$(detect_os)
  local config_dir=$(get_config_dir)

  # Source server variables
  if [ -f "${config_dir}/server_vars" ]; then
    source "${config_dir}/server_vars"
  else
    check_server_config
  fi

  log_info "Deactivating WireGuard server..."

  # Check if the interface is actually running
  if ! ip link show "$SERVER_WG_NIC" &>/dev/null && ! ifconfig "$SERVER_WG_NIC" &>/dev/null 2>&1; then
    log_warning "WireGuard interface $SERVER_WG_NIC is not active."
    return 1
  fi

  # OS-specific deactivation
  if [ "$os" == "macos" ]; then
    # macOS WireGuard deactivation
    log_info "Stopping WireGuard on macOS..."
    sudo wg-quick down "$SERVER_WG_NIC"
  else
    # Linux WireGuard deactivation
    if command -v systemctl >/dev/null 2>&1; then
      log_info "Stopping WireGuard systemd service..."
      systemctl stop wg-quick@${SERVER_WG_NIC}
    else
      # For non-systemd systems
      log_info "Stopping WireGuard with wg-quick..."
      wg-quick down ${SERVER_WG_NIC}
    fi
  fi

  # Verify the interface is down
  if ! ip link show "$SERVER_WG_NIC" &>/dev/null 2>&1 && ! ifconfig "$SERVER_WG_NIC" &>/dev/null 2>&1; then
    log_info "WireGuard server deactivated successfully."
  else
    log_error "Failed to deactivate WireGuard server. Interface $SERVER_WG_NIC is still active."
  fi
}

function restart_server() {
  local os=$(detect_os)
  local config_dir=$(get_config_dir)

  # Source server variables
  if [ -f "${config_dir}/server_vars" ]; then
    source "${config_dir}/server_vars"
  else
    check_server_config
  fi

  log_info "Restarting WireGuard server..."

  # Check if config file exists
  local server_conf="${config_dir}/${SERVER_WG_NIC}-server.conf"
  if [ ! -f "$server_conf" ]; then
    log_error "Configuration file not found: $server_conf"
  fi

  # Validate the configuration file
  log_info "Validating configuration file..."
  if ! wg-quick strip "$server_conf" &>/dev/null; then
    log_warning "Configuration file has potential issues. Attempting to diagnose..."

    # Check for common issues
    if ! grep -q "PrivateKey" "$server_conf"; then
      log_error "Missing PrivateKey in configuration. Please check your configuration file."
    fi

    if ! grep -q "Address" "$server_conf"; then
      log_error "Missing Address in configuration. Please check your configuration file."
    fi

    # Show the configuration file structure (without showing private keys)
    echo -e "\n${ORANGE}Configuration structure:${NC}"
    grep -v "PrivateKey\|PresharedKey" "$server_conf" | cat -n

    # Ask user if they want to continue anyway
    read -rp "Configuration validation failed. Try restart anyway? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
      log_warning "Restart canceled. Please fix your configuration first."
      return 1
    fi
  fi

  # OS-specific restart
  if [ "$os" == "macos" ]; then
    # macOS WireGuard restart
    log_info "Restarting WireGuard on macOS..."
    if ifconfig "$SERVER_WG_NIC" &>/dev/null 2>&1; then
      sudo wg-quick down "$SERVER_WG_NIC"
    fi
    sleep 1
    if sudo wg-quick up "$server_conf"; then
      log_info "WireGuard successfully restarted on macOS."
    else
      log_error "Failed to restart WireGuard on macOS. Check logs above for errors."
    fi
  else
    # Linux WireGuard restart
    if command -v systemctl >/dev/null 2>&1; then
      log_info "Restarting WireGuard systemd service..."

      # Stop first
      systemctl stop wg-quick@${SERVER_WG_NIC}
      sleep 1

      # Try to start and capture error output
      if systemctl start wg-quick@${SERVER_WG_NIC}; then
        log_info "WireGuard systemd service successfully restarted."
      else
        log_warning "Systemd service restart failed. Trying direct wg-quick approach..."
        # Show systemd status for debugging
        systemctl status wg-quick@${SERVER_WG_NIC} --no-pager || true

        # Try direct wg-quick approach
        if ip link show "$SERVER_WG_NIC" &>/dev/null; then
          wg-quick down ${SERVER_WG_NIC}
        fi
        sleep 1
        if wg-quick up "$server_conf"; then
          log_info "WireGuard successfully restarted with wg-quick."
        else
          # Provide more detailed diagnostic information
          log_error "Failed to restart WireGuard. Check configuration file for errors."
          echo -e "\n${ORANGE}Troubleshooting suggestions:${NC}"
          echo "1. Check your configuration file for errors"
          echo "2. Run: journalctl -xeu wg-quick@${SERVER_WG_NIC}.service"
          echo "3. Verify that your firewall allows UDP port ${SERVER_PORT:-51820}"
          echo "4. Make sure there are no IP conflicts"
          return 1
        fi
      fi
    else
      # For non-systemd systems
      log_info "Restarting WireGuard with wg-quick..."
      if ip link show "$SERVER_WG_NIC" &>/dev/null; then
        wg-quick down ${SERVER_WG_NIC}
      fi
      sleep 1
      if wg-quick up "$server_conf"; then
        log_info "WireGuard successfully restarted with wg-quick."
      else
        log_error "Failed to restart WireGuard. Check configuration file for errors."
        return 1
      fi
    fi
  fi

  # Verify the interface is up
  if ip link show "$SERVER_WG_NIC" &>/dev/null 2>&1 || ifconfig "$SERVER_WG_NIC" &>/dev/null 2>&1; then
    log_info "WireGuard server restarted successfully."
    log_info "Interface: ${SERVER_WG_NIC}"
    log_info "To check status: wg show"
    return 0
  else
    log_error "Failed to verify WireGuard interface is active after restart."
    return 1
  fi
}

function upgrade_manager() {
  local os=$(detect_os)
  local current_dir=$(get_config_dir)
  local temp_dir="/tmp/wg-manager-upgrade"
  local repo_url="https://raw.githubusercontent.com/isimtekin/wireguard/main"

  log_info "🔄 Checking for WireGuard Manager updates..."

  # Create temp directory
  mkdir -p "$temp_dir"

  # Determine where the script is installed
  local installed_path=""
  if command -v wg-manager &>/dev/null; then
    installed_path=$(which wg-manager)
    log_info "✅ Found installed WireGuard Manager at: $installed_path"
  else
    log_warning "⚠️  WireGuard Manager is not installed system-wide."
    log_info "   Will update the local script: $0"
    installed_path="$0"
  fi

  # Download the latest version
  log_info "📥 Downloading the latest version..."
  if ! curl -s -o "$temp_dir/wg-manager.sh" "$repo_url/wg-manager.sh"; then
    log_error "❌ Failed to download the latest version. Check your internet connection."
  fi

  # Check if download was successful
  if [ ! -f "$temp_dir/wg-manager.sh" ]; then
    log_error "❌ Download failed. Update aborted."
  fi

  # Make the downloaded file executable
  chmod +x "$temp_dir/wg-manager.sh"

  # Compare versions (if available)
  local current_version=$(grep -o "VERSION=.*" "$installed_path" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
  local new_version=$(grep -o "VERSION=.*" "$temp_dir/wg-manager.sh" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "latest")

  # Check for changes by comparing file contents (ignoring version lines)
  local changed=false
  if diff -q <(grep -v "VERSION=" "$installed_path") <(grep -v "VERSION=" "$temp_dir/wg-manager.sh") >/dev/null; then
    log_info "📊 No significant changes detected between versions."
    changed=false
  else
    log_info "📊 Found differences between current and new version."
    changed=true
  fi

  log_info "📊 Current version: \"${current_version}\""
  log_info "📊 Latest version: \"${new_version}\""

  # If no changes and versions are the same, no need to update
  if [ "$current_version" = "$new_version" ] && [ "$changed" = false ]; then
    log_info "✅ You already have the latest version \"$current_version\"."
    rm -rf "$temp_dir"
    return 0
  fi

  # Ask for confirmation
  read -rp "Do you want to update to the latest version? (y/N): " CONTINUE
  if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
    log_warning "⚠️  Update canceled."
    rm -rf "$temp_dir"
    return 1
  fi

  # Backup the current version
  local backup_path="${installed_path}.backup"
  log_info "📦 Creating backup of current version at: $backup_path"
  cp "$installed_path" "$backup_path"

  # Install the new version
  log_info "🔄 Installing the new version..."
  if ! cp "$temp_dir/wg-manager.sh" "$installed_path"; then
    log_error "❌ Failed to install the new version. Your backup is at: $backup_path"
  fi

  # Make sure permissions are correct
  chmod +x "$installed_path"

  # Clean up
  rm -rf "$temp_dir"

  log_info "✅ WireGuard Manager has been successfully upgraded to version \"${new_version}\"!"
  log_info "   If you encounter any issues, your backup is at: $backup_path"
  log_info "   You can restore it with: cp $backup_path $installed_path"

  return 0
}

function main() {
  local os=$(detect_os)

  # Only check for root if not on macOS or run with sudo on macOS
  if [ "$os" != "macos" ]; then
    check_root
  elif [ "$EUID" -ne 0 ]; then
    log_warning "On macOS, this script should be run with sudo."
    log_warning "Re-running with sudo..."
    exec sudo "$0" "$@"
    exit 1
  fi

  case "$1" in
    install)
      install_wireguard
      ;;
    config)
      create_server_config
      ;;
    add-client)
      add_client
      ;;
    transfer-conf)
      transfer_config
      ;;
    download-conf)
      download_config
      ;;
    list-clients)
      list_clients
      ;;
    activate)
      activate_server
      ;;
    deactivate)
      deactivate_server
      ;;
    restart)
      restart_server
      ;;
    status)
      show_status
      ;;
    upgrade)
      upgrade_manager
      ;;
    help)
      show_usage
      ;;
    *)
      show_usage
      ;;
  esac
}

# Execute main with all arguments
main "$@"