# WireGuard Manager

![WireGuard Logo](https://www.wireguard.com/img/wireguard.svg)

WireGuard Manager is a comprehensive bash script that simplifies the installation, configuration, and management of WireGuard VPN servers and clients. It's designed to work seamlessly on both Linux and macOS systems.

## Features

- 🚀 **Cross-platform compatibility** (Linux and macOS)
- 🔧 **Simple installation** process for WireGuard
- 🔒 **Easy server configuration** with sensible defaults
- 👥 **Client management** to create, list, and transfer client configs
- 📊 **Status monitoring** with detailed information about your server
- 🔄 **Seamless restart** capabilities when configurations change
- 📱 **QR code generation** for easy mobile client setup (when `qrencode` is installed)
- 🖥️ **Multiple distro support** including Ubuntu, Debian, CentOS, Fedora, Arch, and Alpine

## Installation

### Option 1: Quick Start (Running from the current directory)

1. Download the script
   ```bash
   curl -O https://raw.githubusercontent.com/isimtekin/wireguard/main/wg-manager.sh
   chmod +x wg-manager.sh
   ```

2. Install WireGuard
   ```bash
   sudo ./wg-manager.sh install
   ```

### Option 2: System-Wide Installation

Install WireGuard Manager as a system-wide command, making it accessible from any directory:

1. Download both the main script and the installation script
   ```bash
   curl -O https://raw.githubusercontent.com/isimtekin/wireguard/main/wg-manager.sh
   curl -O https://raw.githubusercontent.com/isimtekin/wireguard/main/install.sh
   chmod +x wg-manager.sh install.sh
   ```

2. Run the installation script
   ```bash
   sudo ./install.sh
   ```

3. Now you can run WireGuard Manager from anywhere using:
   ```bash
   sudo wg-manager status
   sudo wg-manager add-client
   # etc...
   ```

**Manual System-Wide Installation:**

If you prefer to install manually:

```bash
sudo cp wg-manager.sh /usr/local/bin/wg-manager
sudo chmod +x /usr/local/bin/wg-manager
```

## Basic Setup Guide

Setting up your WireGuard VPN is easy with WireGuard Manager:

1. Install WireGuard on your system
   ```bash
   sudo wg-manager install
   ```

2. Create your server configuration
   ```bash
   sudo wg-manager config
   ```
   Follow the prompts and provide information or accept the defaults.

3. Add a client
   ```bash
   sudo wg-manager add-client
   ```
   Enter a name for your client when prompted.

4. Start the WireGuard server
   ```bash
   sudo wg-manager activate
   ```

5. Check that everything is working
   ```bash
   sudo wg-manager status
   ```

## Usage

```
WireGuard Manager Script v1.0.0

Usage: ./wg-manager.sh COMMAND

Commands:
  install             Install WireGuard on the current system
  config              Create WireGuard server configuration
  add-client          Add a new client to WireGuard server
  transfer-conf       Transfer a client config from server to destination
  download-conf       Download a client config from server to local machine
  list-clients        List all existing WireGuard clients
  status              Show current WireGuard status and configuration summary
  activate            Start the WireGuard server
  deactivate          Stop the WireGuard server
  restart             Restart the WireGuard server
  upgrade             Check for updates and upgrade to the latest version
  help                Show this help message
```

## Detailed Guide

### Installing WireGuard

The script detects your operating system and installs WireGuard using the appropriate package manager:

```bash
sudo wg-manager install
```

### Configuring the Server

The configuration process will prompt you for the necessary information, providing sensible defaults:

```bash
sudo wg-manager config
```

You'll be asked for:
- Public IP address (auto-detected)
- Network interface (auto-detected)
- WireGuard interface name (default: wg0)
- Private subnet (default: 10.0.0.0/24)
- Server IP within the subnet (default: 10.0.0.1)
- UDP port (default: 51820)
- Client DNS server (default: 1.1.1.1)

### Adding Clients

To add a new client:

```bash
sudo wg-manager add-client
```

You'll be prompted for a client name, and the script will:
1. Generate keys and configurations
2. Add the client to the server config
3. Create a downloadable configuration file
4. Generate a QR code if `qrencode` is installed
5. Offer to restart the server to apply changes

### Managing the Server

**Starting the server:**
```bash
sudo wg-manager activate
```

**Stopping the server:**
```bash
sudo wg-manager deactivate
```

**Restarting the server:**
```bash
sudo wg-manager restart
```

**Checking server status:**
```bash
sudo wg-manager status
```

**Upgrading to the latest version:**
```bash
sudo wg-manager upgrade
```
This will check for updates, download the latest version, and create a backup of your current version before upgrading.

### Transferring Configurations

**Downloading a client config:**
```bash
sudo wg-manager download-conf
```

**Transferring a config between servers:**
```bash
sudo wg-manager transfer-conf
```

**Listing existing clients:**
```bash
sudo wg-manager list-clients
```

## Configuration Files

All configurations are stored in:
- Linux: `/etc/wireguard/`
- macOS: `/usr/local/etc/wireguard/`

Key files include:
- `wg0-server.conf`: Main server configuration
- `privatekey`, `publickey`: Server keys
- `server_vars`: Saved server variables for reuse
- `<client_name>.conf`: Client configurations
- `<client_name>.zip`: Zipped client configurations (if `zip` is installed)

## Client Setup

### Mobile Devices

1. Add a client using the script:
   ```bash
   sudo wg-manager add-client
   ```

2. If you have `qrencode` installed, a QR code will be displayed. Scan this QR code using the WireGuard mobile app on your device.

3. If you don't have `qrencode` installed, you can download the configuration file and manually import it:
   ```bash
   sudo wg-manager download-conf
   ```

### Desktop Clients

1. Add a client using the script:
   ```bash
   sudo wg-manager add-client
   ```

2. Download the configuration file:
   ```bash
   sudo wg-manager download-conf
   ```

3. Import the `.conf` file into your WireGuard client software.

## Troubleshooting

If you encounter issues:

1. Check the server status:
   ```bash
   sudo wg-manager status
   ```

2. Verify that your firewall allows UDP traffic on your configured port (default 51820)

3. If clients cannot connect, try restarting the server:
   ```bash
   sudo wg-manager restart
   ```

4. Ensure your server's public IP hasn't changed. If it has, you'll need to update client configurations.

5. Common issues:
    - **Client can't connect**: Check the server's public IP and port forwarding
    - **No internet on client**: Check the AllowedIPs and server's forwarding settings
    - **Connection drops**: Check the PersistentKeepalive setting (default is 25 seconds)

## Common Scenarios

### Setting up a new VPN server

```bash
sudo wg-manager install
sudo wg-manager config
sudo wg-manager add-client
sudo wg-manager activate
```

### Adding multiple clients

```bash
sudo wg-manager add-client  # Add first client
sudo wg-manager add-client  # Add second client
sudo wg-manager restart     # Only needed if you didn't restart after adding clients
```

### Checking if clients are connected

```bash
sudo wg-manager status
# Look for "Active Interface Details" section
```

### Updating after server IP changes

If your server's public IP changes:

1. Check the current status to see both IPs:
   ```bash
   sudo wg-manager status
   ```

2. You'll need to update client configurations or create new ones

## Security Considerations

- The script generates strong keys for both server and clients
- Private keys are stored with restricted permissions (600)
- Config directory permissions are restricted (700)
- For production use, consider implementing additional firewall rules
- Consider setting up regular backups of your configuration directory

## Platform Specific Notes

### Linux

- Ensure your kernel supports WireGuard (Linux kernel 5.6+ has built-in support)
- For older kernels, the script will install appropriate DKMS modules
- Make sure forwarding is enabled: `sysctl -w net.ipv4.ip_forward=1`
- Check your distribution's firewall settings to allow the WireGuard UDP port

### macOS

- Requires Homebrew for installation
- May require sudo for most operations
- Network interface names will be different from Linux (en0, en1, etc.)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Based on the original work by [isimtekin](https://github.com/isimtekin/wireguard)
- [WireGuard](https://www.wireguard.com/) - The incredible VPN technology
- The open-source community for feedback and contributions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.