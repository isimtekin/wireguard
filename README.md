# WireGuard Install & Client Manager Script

This project provides a **Bash script** to simplify the setup, configuration, and management of a WireGuard VPN server and its clients. It is designed to be used on **Linux** and **macOS** systems, with support for interactive and scripted modes.

---

## 🚀 Features

- Install WireGuard based on detected OS (Linux/macOS)
- Generate server configuration with customizable subnet
- Create and register clients
- Download and transfer client `.conf` files
- List registered clients

---

## 🖥️ Supported Operating Systems

This script supports the following operating systems:

- Ubuntu (18.04+)
- Debian (10+)
- Fedora (32+)
- CentOS / Rocky / AlmaLinux (8+)
- Arch Linux
- Alpine Linux
- macOS (via Homebrew)

---

## 📦 Installation

Clone the repository and give the script execute permissions:

```bash
git clone https://github.com/isimtekin/wireguard.git
cd wireguard
chmod +x wg.sh
```

---

## 🛠️ Commands & Usage

### `install`
Install WireGuard and its dependencies.
```bash
./wg.sh install
```

### `config`
Generate server keys and create the WireGuard server configuration.
You will be prompted to enter:
- Server public IP
- Interface name
- VPN subnet (e.g., `10.0.0`)
- Server IP last octet (e.g., `1`)
- Listen port (default: `51820`)
- DNS for clients (default: `1.1.1.1`)

```bash
./wg.sh config
```

### `add-client`
Create a new client:
- Generates keys
- Appends the client to server config
- Saves client `.conf` file

```bash
./wg.sh add-client
```

### `list-clients`
Show a list of all clients registered in server config:
```bash
./wg.sh list-clients
```

### `download-conf`
Download a client's configuration from a remote server to local machine:
```bash
./wg.sh download-conf
```
You will be prompted for:
- Server IP
- Client name

### `transfer-conf`
Fetch a client config from a server and upload to another destination server.
Useful for provisioning another machine.
```bash
./wg.sh transfer-conf
```
You will be prompted for:
- Server IP
- Destination IP
- Client name

---

## 📂 File Locations

- Server configuration: `/etc/wireguard/wg0-server.conf`
- Client configurations: `/etc/wireguard/<client-name>.conf`
- Keys: `/etc/wireguard/privatekey`, `/etc/wireguard/publickey`

---

## ✅ Example Workflow

1. On the VPN server:
```bash
./wg.sh install
./wg.sh config
./wg.sh add-client
```

2. On your local machine:
```bash
./wg.sh download-conf
# or to push it to another client machine
./wg.sh transfer-conf
```

---

## 🧩 Requirements
- Bash 4+
- `wireguard` package (installed via script)
- `scp`, `ssh`, `grep`, `cut`, `nl`
- `zip` (optional if archiving configs)

---

## 🛡️ Notes
- This script must be run as `root` or with `sudo`, except on macOS.
- All client configurations are stored with `.conf` extension and follow standard WireGuard formatting.

---

## 📄 License
MIT License

---

Made with ❤️ for simple WireGuard setups.

