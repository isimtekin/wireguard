#!/bin/bash

# WireGuard Manager Installation Script
# This script copies the wg-manager.sh file to an appropriate bin directory
# and makes it executable for both Linux and macOS

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Detect OS
if [ "$(uname)" == "Darwin" ]; then
  OS="macos"
  # For macOS, we need to check if Homebrew bin directory exists
  if [ -d "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
  elif [ -d "/opt/homebrew/bin" ]; then
    # M1/M2 Macs may use this path
    INSTALL_DIR="/opt/homebrew/bin"
  else
    INSTALL_DIR="/usr/local/bin"
    echo -e "${YELLOW}Warning: Could not find Homebrew bin directory. Using ${INSTALL_DIR} instead.${NC}"
    mkdir -p "$INSTALL_DIR" 2>/dev/null || true
  fi
else
  OS="linux"
  INSTALL_DIR="/usr/local/bin"
fi

# Root privilege check - handle both Linux and macOS
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script requires root privileges. Please run with 'sudo'.${NC}"
  exit 1
fi

# Current location of the script
CURRENT_DIR=$(pwd)
SCRIPT_PATH="${CURRENT_DIR}/wg-manager.sh"

# Check if the file exists
if [ ! -f "$SCRIPT_PATH" ]; then
  echo -e "${RED}Error: ${SCRIPT_PATH} not found.${NC}"
  echo -e "Make sure you run this script in the same directory as wg-manager.sh."
  exit 1
fi

# Create the target directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy the script and make it executable
cp "$SCRIPT_PATH" "${INSTALL_DIR}/wg-manager"
chmod +x "${INSTALL_DIR}/wg-manager"

# Check if the installation was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}WireGuard Manager has been successfully installed!${NC}"
  echo -e "${GREEN}Installation directory: ${INSTALL_DIR}${NC}"

  # Check if the installation directory is in PATH
  if echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo -e "${GREEN}You can now run the 'wg-manager' command from any directory.${NC}"
    echo -e "Example: ${GREEN}sudo wg-manager status${NC}"
  else
    echo -e "${YELLOW}Warning: ${INSTALL_DIR} is not in your PATH.${NC}"
    echo -e "You may need to add it to your PATH or use the full path to execute the command."
    echo -e "Full path example: ${GREEN}sudo ${INSTALL_DIR}/wg-manager status${NC}"
  fi
else
  echo -e "${RED}Installation failed. Please check permissions and try again.${NC}"
  exit 1
fi

# macOS specific instructions
if [ "$OS" == "macos" ]; then
  echo -e "\n${YELLOW}macOS Notice:${NC}"
  echo -e "On macOS, you will need to run the script with sudo:"
  echo -e "Example: ${GREEN}sudo wg-manager status${NC}"
fi

exit 0