#!/bin/bash
# "made by @oem"
# This script configures mgetty and PPP for a dial-up server,
# including network forwarding and iptables rules.

# Define port, speed, maininterfaceport, rings, user, password, ServerName, and Client local IP address
# Note: In the systemd service file, %i will be replaced by the instance name (e.g., ttyUSB0).
# So, 'port' should be just 'ttyUSB0' here without '/dev/'.
port="ttyUSB0"
# Default speed is 112000
speed="112000"
# Your main internet connection to find it use "ip a"
maininterfaceport="eth0"
# How many rings until the modem answers
rings="4"
# Your user name for ppp
User="dialup"
# Your password for ppp
Password="secret"
# ServerName: your user@"ServerName". Don't put @ in it.
ServerName="ServerName"
# local client ip address
ip="192.168.1.201"
# --- Pre-installation Checks and Preparations ---
echo "--- Checking for sudo and common utilities ---"
if ! command -v sudo &> /dev/null; then
    echo "Error: sudo command not found. Please install sudo or run as root."
    exit 1
fi
if ! command -v apt &> /dev/null; then
    echo "Error: apt command not found. This script is for Debian/Ubuntu-based systems."
    exit 1
fi
# --- Update and install required packages ---
echo "--- Updating package lists and installing required packages ---"
sudo apt update || { echo "Error: apt update failed."; exit 1; }
sudo apt install -y mgetty ppp iptables-persistent || { echo "Error: Failed to install mgetty, ppp, or iptables-persistent."; exit 1; }
# Add user to dialout group
echo "--- Adding current user to 'dialout' group ---"
sudo usermod -a -G dialout "$USER" || { echo "Error: Failed to add user to dialout group."; exit 1; }
echo "Please log out and log back in for group changes to take effect if you encounter permission issues."
# --- Configure mgetty ---
echo "--- Configuring mgetty ---"
# Note: mgetty.config expects the full /dev/path
sudo tee /etc/mgetty/mgetty.config > /dev/null <<EOF
debug 9
port /dev/$port
 port-owner root
 port-group dialout
 speed $speed
 data-only Y
 rings $rings
 modem-check-time 160
 ignore-carrier no
 init-chat "" ATZ OK
EOF
if [ $? -ne 0 ]; then echo "Error: Failed to configure mgetty.config."; exit 1; fi
# Update login.config for AutoPPP
echo "--- Updating mgetty login.config for AutoPPP ---"
CONFIG_FILE="/etc/mgetty/login.config"
# Correctly uses the pppd options template path
sudo sed -i 's|/AutoPPP/ -[[:space:]]*a_ppp[[:space:]]*/usr/sbin/pppd.*|/AutoPPP/ - a_ppp /usr/sbin/pppd file /etc/ppp/options.%i|' "$CONFIG_FILE" || { echo "Error: Failed to update login.config."; exit 1; }
# --- Configure PPP options file ---
echo "--- Configuring PPP options for $port ---"
OPTIONS_FILE="/etc/ppp/options.$port"
# Warn if the file already exists to prevent accidental overwrites
if [ -f "$OPTIONS_FILE" ]; then
    echo "Warning: PPP options file '$OPTIONS_FILE' already exists. Overwriting."
fi
sudo tee "$OPTIONS_FILE" > /dev/null <<EOF
# Define the DNS server for the client to use
ms-dns 8.8.8.8
# Local and remote IP addresses (Server IP:Client IP)
192.168.1.1:192.168.1.2
# async character map should be 0, which disables escaping of standard control characters.
asyncmap 0
# Require authentication
auth
# Use hardware flow control
crtscts
# We want exclusive access to the modem device
lock
# Show pap passwords in log files to help with debugging (Remove in production!)
show-password
# Require the client to authenticate with PAP
+pap
# Enable debugging if you're having trouble with auth
debug
# Heartbeat for control messages, used to determine if the client connection has dropped
lcp-echo-interval 30
lcp-echo-failure 4
# Cache the client mac address in the arp system table
proxyarp
# Disable the IPXCP and IPX protocols.
noipx
EOF
if [ $? -ne 0 ]; then echo "Error: Failed to write to PPP options file '$OPTIONS_FILE'."; exit 1; fi
# --- Configure PAP secrets ---
echo "--- Configuring PAP secrets ---"
# The format is: client_username    server_name    password    allowed_ip_address
# This allows 'User' to connect to 'ServerName' using 'Password' and be assigned 'ip'.
sudo tee /etc/ppp/pap-secrets > /dev/null <<EOF
$User    $ServerName   $Password    $ip
EOF
if [ $? -ne 0 ]; then echo "Error: Failed to configure pap-secrets."; exit 1; }
# --- Enable IP Forwarding ---
echo "--- Enabling IPv4 forwarding ---"
# Write to sysctl.conf and also apply immediately using sysctl -w
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null || { echo "Error: Failed to write to sysctl.conf."; exit 1; }
sudo sysctl -w net.ipv4.ip_forward=1 || { echo "Error: Failed to set net.ipv4.ip_forward."; exit 1; }
sudo sysctl -p # Reload all settings from sysctl.conf
if [ $? -ne 0 ]; then echo "Error: Failed to apply sysctl settings."; exit 1; }
# --- Configure iptables rules ---
echo "--- Configuring iptables rules ---"
# Ensure iptables kernel modules are loaded
echo "Attempting to load iptables kernel modules..."
sudo modprobe ip_tables || echo "Warning: Could not load ip_tables module. iptables might not work."
sudo modprobe iptable_filter || echo "Warning: Could not load iptable_filter module. iptables might not work."
sudo modprobe nf_conntrack || echo "Warning: Could not load nf_conntrack module. iptables might not work." # For RELATED,ESTABLISHED state
# Apply iptables rules
# Use ppp+ to match any ppp interface (e.g., ppp0, ppp1, etc.)
sudo iptables -A FORWARD -i ppp+ -o "$maininterfaceport" -j ACCEPT || { echo "Error: Failed to add iptables FORWARD rule 1."; exit 1; }
sudo iptables -A FORWARD -i "$maininterfaceport" -o ppp+ -m state --state RELATED,ESTABLISHED -j ACCEPT || { echo "Error: Failed to add iptables FORWARD rule 2."; exit 1; }
# Save iptables rules
echo "--- Saving iptables rules ---"
sudo netfilter-persistent save || { echo "Error: Failed to save netfilter-persistent rules. Check if netfilter-persistent is correctly installed and running."; exit 1; }
# --- Create and Enable mgetty Systemd Service ---
echo "--- Creating mgetty Systemd Service File ---"
# Define the path for the systemd service file
SYSTEMD_SERVICE_FILE="/etc/systemd/system/mgetty@.service"
# Use tee to create the systemd service file with the provided content
sudo tee "$SYSTEMD_SERVICE_FILE" > /dev/null <<'EOF'
[Unit]
Description=External Modem %I
Documentation=man:mgetty(8)
Requires=systemd-udev-settle.service
After=systemd-udev-settle.service
[Service]
Type=simple
ExecStart=/sbin/mgetty /dev/%i
Restart=always
PIDFile=/var/run/mgetty.pid.%i
[Install]
WantedBy=multi-user.target
EOF
if [ $? -ne 0 ]; then echo "Error: Failed to create systemd service file."; exit 1; }
echo "--- Reloading Systemd Daemon ---"
sudo systemctl daemon-reload || { echo "Error: Failed to reload systemd daemon."; exit 1; }
echo "--- Enabling and Starting mgetty Service ---"
# Now that systemd is configured, enable and start the service
# The 'port' variable (e.g., ttyUSB0) is used as the instance for the service template.
sudo systemctl enable mgetty@$port.service || { echo "Error: Failed to enable mgetty service."; exit 1; }
sudo systemctl start mgetty@$port.service || { echo "Error: Failed to start mgetty service."; exit 1; }
echo "--- Script execution finished ---"
echo "Done!"
echo "Please check the system logs (e.g., 'journalctl -xe') and mgetty logs (e.g., '/var/log/mgetty.log.$port')."
echo "If it's still not working, please consult the Troubleshooting section on GitHub."