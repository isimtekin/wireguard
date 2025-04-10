#!/bin/bash

# WireGuard server/client installer script template
# https://github.com/isimtekin/wireguard

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

function usage() {
  echo -e "${ORANGE}Usage: $0 {install|config|add-client|transfer-conf <server_ip> <destination_ip> <client_name>}${NC}"
}

function isRoot() {
  if [ "${EUID}" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
  fi
}

function detectOS() {
  if [ "$(uname)" == "Darwin" ]; then
    OS="macos"
  elif [ -e /etc/os-release ]; then
    source /etc/os-release
    OS=${ID}
    VERSION_ID=${VERSION_ID}
  else
    echo -e "${RED}Unable to detect OS. Exiting.${NC}"
    exit 1
  fi
}

function installWireGuard() {
  echo -e "${GREEN}Installing WireGuard for ${OS}${NC}"
  case $OS in
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
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}Homebrew is not installed. Please install Homebrew first: https://brew.sh${NC}"
        exit 1
      fi
      brew install wireguard-tools
      ;;
    *)
      echo -e "${RED}OS $OS not supported.${NC}"
      exit 1
      ;;
  esac
  echo -e "${GREEN}WireGuard installed successfully.${NC}"
}

function createServerConfig() {
  echo -e "${GREEN}Creating WireGuard server configuration...${NC}"

  GUESS_IP=$(ip -4 addr | grep inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
  GUESS_IFACE=$(ip route get 1 | awk '{print $5; exit}')

  read -rp "Public IP (auto-detected: $GUESS_IP): " SERVER_PUB_IP
  SERVER_PUB_IP=${SERVER_PUB_IP:-$GUESS_IP}

  read -rp "Public Network Interface (auto-detected: $GUESS_IFACE): " SERVER_PUB_NIC
  SERVER_PUB_NIC=${SERVER_PUB_NIC:-$GUESS_IFACE}

  read -rp "WireGuard Interface Name [wg0]: " SERVER_WG_NIC
  SERVER_WG_NIC=${SERVER_WG_NIC:-wg0}

  read -rp "Private Subnet Base (e.g. 10.0.0): " PRIVATE_SUBNET_BASE
  PRIVATE_SUBNET_BASE=${PRIVATE_SUBNET_BASE:-10.0.0}

  read -rp "Server Host IP (last octet, e.g. 1): " SERVER_HOST_IP
  SERVER_HOST_IP=${SERVER_HOST_IP:-1}

  SERVER_WG_IP="$PRIVATE_SUBNET_BASE.$SERVER_HOST_IP/24"
  ALLOWED_IPS="$PRIVATE_SUBNET_BASE.0/24"

  read -rp "UDP Port [51820]: " SERVER_PORT
  SERVER_PORT=${SERVER_PORT:-51820}

  read -rp "Client DNS [1.1.1.1]: " CLIENT_DNS
  CLIENT_DNS=${CLIENT_DNS:-1.1.1.1}

  mkdir -p /etc/wireguard
  chmod 700 /etc/wireguard

  PRIVATE_KEY=$(wg genkey)
  PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

  echo "$PRIVATE_KEY" > /etc/wireguard/privatekey
  echo "$PUBLIC_KEY" > /etc/wireguard/publickey
  chmod 600 /etc/wireguard/privatekey

  CONFIG_FILE="/etc/wireguard/${SERVER_WG_NIC}-server.conf"

  cat > "$CONFIG_FILE" <<EOL
[Interface]
Address = $SERVER_WG_IP
ListenPort = $SERVER_PORT
PrivateKey = $PRIVATE_KEY

# SaveConfig = true
# PostUp   = iptables -A FORWARD -i $SERVER_WG_NIC -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
# PostDown = iptables -D FORWARD -i $SERVER_WG_NIC -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_PUB_NIC -j MASQUERADE
EOL

  echo -e "${GREEN}Server config created at: $CONFIG_FILE${NC}"
}

function addClient() {
  echo -e "${GREEN}Creating new WireGuard client configuration...${NC}"
  read -rp "Client name: " CLIENT_NAME

  CLIENT_PRIV_KEY=$(wg genkey)
  CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)
  CLIENT_PRESHARED_KEY=$(wg genpsk)

  CLIENT_LAST_OCTET=$(shuf -i 2-254 -n 1)
  CLIENT_IPv4="$PRIVATE_SUBNET_BASE.$CLIENT_LAST_OCTET/32"

  CLIENT_CONFIG_FILE="/etc/wireguard/${CLIENT_NAME}.conf"

  cat > "$CLIENT_CONFIG_FILE" <<EOL
[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_IPv4
DNS = $CLIENT_DNS

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = $SERVER_PUB_IP:$SERVER_PORT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
EOL

  echo -e "${GREEN}Client config created at: $CLIENT_CONFIG_FILE${NC}"

  {
    echo ""
    echo "### Client $CLIENT_NAME"
    echo "[Peer]"
    echo "PublicKey = $CLIENT_PUB_KEY"
    echo "PresharedKey = $CLIENT_PRESHARED_KEY"
    echo "AllowedIPs = $CLIENT_IPv4"
  } >> "/etc/wireguard/${SERVER_WG_NIC}-server.conf"

  # Zip the config
  ZIP_FILE="/etc/wireguard/${CLIENT_NAME}.zip"
  zip -j "$ZIP_FILE" "$CLIENT_CONFIG_FILE" >/dev/null

  echo -e "${GREEN}Client added to server config.${NC}"
  echo -e "\nYou can download the client config with the following command from your local machine:\n"
  echo -e "${ORANGE}scp root@$SERVER_PUB_IP:$ZIP_FILE ./ ${NC}"
  echo -e "\nThen upload it to the target machine (B) with:\n"
  echo -e "${ORANGE}scp ./$(basename $ZIP_FILE) root@<B_MACHINE_IP>:/desired/path/${NC}\n"
}

function transferConf() {
  read -rp "Server IP: " SERVER_IP
  read -rp "Destination IP: " DEST_IP
  read -rp "Client name: " CLIENT_NAME

  CONF_FILE="${CLIENT_NAME}.conf"

  echo -e "${GREEN}Fetching $CONF_FILE from $SERVER_IP...${NC}"
  scp root@$SERVER_IP:/etc/wireguard/$CONF_FILE ./

  echo -e "${GREEN}Uploading $CONF_FILE to $DEST_IP:/etc/wireguard/${NC}"
  scp "./$CONF_FILE" root@$DEST_IP:/etc/wireguard/

  echo -e "${GREEN}Done! $CONF_FILE transferred from $SERVER_IP to $DEST_IP.${NC}"
  echo -e "\nTo activate the client on $DEST_IP, SSH into it and run:${NC}"
  echo -e "${ORANGE}sudo wg-quick up $CLIENT_NAME${NC}"

  rm -f "$CONF_FILE"
}

function downloadConf() {
  read -rp "Server IP: " SERVER_IP
  read -rp "Client name: " CLIENT_NAME

  CONF_FILE="${CLIENT_NAME}.conf"
  echo -e "${GREEN}Downloading $CONF_FILE from $SERVER_IP...${NC}"
  scp root@$SERVER_IP:/etc/wireguard/$CONF_FILE ./
  echo -e "${GREEN}Download complete. File saved as ./$CONF_FILE${NC}"
}

function listClients() {
  echo -e "${GREEN}Listing existing WireGuard clients...${NC}"
  grep -E '^### Client' /etc/wireguard/*.conf 2>/dev/null | cut -d ':' -f2- | cut -d ' ' -f3 | nl -w2 -s') '
}

function main() {
  detectOS
  if [[ "$OS" != "macos" ]]; then
    isRoot
  fi

  case "$1" in
    install)
      installWireGuard
      ;;
    config)
      createServerConfig
      ;;
    add-client)
      addClient
      ;;
    transfer-conf)
      transferConf
      ;;
    download-conf)
      downloadConf
      ;;
    list-clients)
      listClients
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"