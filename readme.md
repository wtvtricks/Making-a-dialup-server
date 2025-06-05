<div contenteditable="false" translate="no" class="ProseMirror"><h1>Dial-Up Server on debian</h1><p>This repository documents the process of setting up a functional dial-up server on debian linux, allowing vintage clients (like old PCs) to connect and access the internet. This guide was tested using a <strong>USR 3453c modem</strong> connected via <strong><code>/dev/ttyUSB0</code></strong>.**NOTE**: Some of these configs are not made by me it made by @Famicoman.</p><h2>Table of Contents</h2><ol><li><p><a href="#introduction" title="null">Introduction</a></p></li><li><p><a href="#prerequisites" title="null">Prerequisites</a></p></li><li><p><a href="#installation" title="null">Installation</a></p></li><li><p><a href="#configuration" title="null">Configuration</a></p><ul><li><p><a href="#modem-detection--permissions" title="null">Modem Detection &amp; Permissions</a></p></li><li><p><a href="#mgetty-configuration" title="null"><code>mgetty</code> Configuration</a></p></li><li><p><a href="#ppp-configuration" title="null"><code>ppp</code> Configuration</a></p></li><li><p><a href="#ip-forwarding--nat-internet-access" title="null">IP Forwarding &amp; NAT (Internet Access)</a></p></li></ul></li><li><p><a href="#starting--managing-the-service" title="null">Starting &amp; Managing the Service</a></p></li><li><p><a href="#troubleshooting" title="null">Troubleshooting</a></p></li><li><p><a href="#security-considerations" title="null">Security Considerations</a></p></li></ol><h2>1. Introduction</h2><p>This project enables a Linux Mint machine to act as a dial-up Internet Service Provider (ISP). By configuring <code>mgetty</code> to answer incoming calls and <code>pppd</code> to establish network connections, older devices can dial into your server and gain internet access.</p><h2>2. Prerequisites</h2><p>Before you start, ensure you have:</p><ul><li><p>A fresh installation of <strong>Linux Mint</strong>.</p></li><li><p>A <strong>USR Modem or any modem</strong> connected to a USB port.</p></li><li><p>An active <strong>analog telephone line</strong> connected to your modem.</p></li><li><p><code>sudo</code> (administrative) privileges on your Linux Mint system.</p></li><li><p>Basic familiarity with the Linux terminal and text editors (e.g., <code>nano</code>).</p></li></ul><h2>3. Installation</h2><p>First, update your package lists and install the necessary software:</p><pre><code>sudo apt update
sudo apt install mgetty ppp iptables-persistent
<br class="ProseMirror-trailingBreak"></code></pre><h2>4. Configuration</h2><h3>Modem Detection &amp; Permissions</h3><ol><li><p><strong>Verify Modem Detection:</strong>
Ensure your modem is detected as <code>/dev/ttyUSB0</code>.</p><pre><code>dmesg | grep ttyUSB
lsusb
<br class="ProseMirror-trailingBreak"></code></pre><p>You should see output confirming its detection.</p></li><li><p><strong>Check/Add User to <code>dialout</code> Group:</strong>
Your user needs access to the modem device.</p><pre><code>ls -l /dev/ttyUSB0
groups
<br class="ProseMirror-trailingBreak"></code></pre><p>If your user is not in <code>dialout</code>, add them and then <strong>log out and log back in</strong>:</p><pre><code>sudo usermod -a -G dialout $USER
<br class="ProseMirror-trailingBreak"></code></pre></li></ol><h3><code>mgetty</code> Configuration</h3><p><code>mgetty</code> answers calls and hands off to <code>pppd</code>.</p><ol><li><p><strong>Edit <code>mgetty.config</code>:</strong></p><pre><code>sudo nano /etc/mgetty/mgetty.config
<br class="ProseMirror-trailingBreak"></code></pre><p>Ensure these lines are present and correctly configured (uncomment if needed):</p><pre><code>port ttyUSB0
port-owner root
port-group dialout
speed 115200
data-only Y
rings 4
modem-check-time 160
ignore-carrier no
init-chat "" ATZ OK
debug 9 # High debug level, useful for troubleshooting
<br class="ProseMirror-trailingBreak"></code></pre></li><li><p><strong>Edit <code>login.config</code>:</strong>
This file tells <code>mgetty</code> to pass PPP connections to <code>pppd</code>.</p><pre><code>sudo nano /etc/mgetty/login.config
<br class="ProseMirror-trailingBreak"></code></pre><p>Add or ensure this exact line is present:</p><pre><code>/AutoPPP/ - a_ppp /usr/sbin/pppd file /etc/ppp/options.ttyUSB0
<br class="ProseMirror-trailingBreak"></code></pre></li></ol><h3><code>ppp</code> Configuration</h3><p><code>pppd</code> manages the actual network connection for the dial-in client.</p><ol><li><p><strong>Create/Edit <code>options.ttyUSB0</code>:</strong>
This file defines PPP options for the <code>ttyUSB0</code> connection.</p><pre><code>sudo nano /etc/ppp/options.ttyUSB0
<br class="ProseMirror-trailingBreak"></code></pre><p>Add the following content (adjust IP addresses as needed):</p><pre><code># Define the DNS server for the client to use
ms-dns 8.8.8.8
# Local and remote IP addresses (Server IP:Client IP)
192.168.200.1:192.168.200.2
# async character map should be 0
asyncmap 0
# Require authentication
auth
# Use hardware flow control
crtscts
# We want exclusive access to the modem device
lock
# Show pap passwords in log files to help with debugging (Remove in production!)
show-password
# Require the client to authenticate with PAP (as found in debugging)
+pap
# If you are having trouble with auth enable debugging
debug
# Heartbeat for control messages, used to determine if the client connection has dropped
lcp-echo-interval 30
lcp-echo-failure 4
# Cache the client mac address in the arp system table
proxyarp
# Disable the IPXCP and IPX protocols.
noipx
<br class="ProseMirror-trailingBreak"></code></pre></li><li><p><strong>Configure PAP Authentication Secrets:</strong>
Since <code>+pap</code> is used, credentials must be in <code>/etc/ppp/pap-secrets</code>.</p><pre><code>sudo nano /etc/ppp/pap-secrets
<br class="ProseMirror-trailingBreak"></code></pre><p>Add a line for each allowed dial-in user. The format is:
<code>client_username   server_name   password   IP_address</code></p><p><strong>Important:</strong></p><ul><li><p><code>client_username</code>: The username entered on the dial-in client.</p></li><li><p><code>server_name</code>: Your Linux Mint server's exact hostname (run <code>hostname</code> to confirm).</p></li><li><p><code>password</code>: The password entered on the dial-in client.</p></li><li><p><code>IP_address</code>: <code>*</code> allows any IP.</p></li></ul><p>Example (replace with your actual hostname, username, and password):</p><pre><code># ClientName    ServerName              Password            IPAddresses
my_dial_user    oem-ASUS-ROG-GAMEING    MyStrongPassw0rd    *
<br class="ProseMirror-trailingBreak"></code></pre></li></ol><h3>IP Forwarding &amp; NAT (Internet Access)</h3><p>To allow dial-up clients to access the internet through your server, you need to enable IP forwarding and set up NAT.</p><ol><li><p><strong>Enable IP Forwarding:</strong></p><pre><code>sudo nano /etc/sysctl.conf
<br class="ProseMirror-trailingBreak"></code></pre><p>Uncomment or add:</p><pre><code>net.ipv4.ip_forward=1
<br class="ProseMirror-trailingBreak"></code></pre><p>Save, exit, and apply changes:</p><pre><code>sudo sysctl -p
<br class="ProseMirror-trailingBreak"></code></pre></li><li><p><strong>Set up NAT with <code>iptables</code>:</strong>
Replace <code>enp9s0</code> with your main internet-connected interface name (e.g., <code>eth0</code>, <code>wlan0</code>). Find it using <code>ip a</code>.</p><pre><code># Masquerade (NAT) traffic from ppp0 out to your main internet interface
sudo iptables -t nat -A POSTROUTING -o enp9s0 -j MASQUERADE

# Allow forwarded traffic from ppp0 to your main interface
sudo iptables -A FORWARD -i ppp0 -o enp9s0 -j ACCEPT

# Allow established/related return traffic
sudo iptables -A FORWARD -i enp9s0 -o ppp0 -m state --state RELATED,ESTABLISHED -j ACCEPT
<br class="ProseMirror-trailingBreak"></code></pre></li><li><p><strong>Save <code>iptables</code> Rules:</strong></p><pre><code>sudo netfilter-persistent save
<br class="ProseMirror-trailingBreak"></code></pre></li></ol><h2>5. Starting &amp; Managing the Service</h2><p><code>mgetty</code> uses a templated systemd service.</p><ol><li><p><strong>Ensure <code>mgetty@ttyUSB0.service</code> is enabled and started:</strong></p><pre><code>sudo systemctl enable mgetty@ttyUSB0.service
sudo systemctl start mgetty@ttyUSB0.service
<br class="ProseMirror-trailingBreak"></code></pre></li><li><p><strong>Check Status:</strong></p><pre><code>sudo systemctl status mgetty@ttyUSB0.service
<br class="ProseMirror-trailingBreak"></code></pre><p>It should show <code>Active: active (running)</code>.</p></li><li><p><strong>Disable unused services:</strong> If you have <code>mgetty@ttyUSB1.service</code> or a custom <code>mgetty-ttyUSB0.service</code> (from earlier troubleshooting), disable and remove them to avoid conflicts and unnecessary resource usage.</p><pre><code># Example for a custom service, if you created one:
# sudo systemctl stop mgetty-ttyUSB0.service
# sudo systemctl disable mgetty-ttyUSB0.service
# sudo rm /etc/systemd/system/mgetty-ttyUSB0.service
# sudo systemctl daemon-reload

# Example for ttyUSB1 if you don't have a modem there:
# sudo systemctl stop mgetty@ttyUSB1.service
# sudo systemctl disable mgetty@ttyUSB1.service
<br class="ProseMirror-trailingBreak"></code></pre></li></ol><h2>6. Troubleshooting</h2><ul><li><p><strong>Modem not detected/<code>ttyUSB0</code> missing:</strong> Check physical connection, modem power, and <code>dmesg | grep ttyUSB</code>.</p></li><li><p><strong><code>mgetty</code> not answering/starting:</strong></p><ul><li><p>Check <code>sudo systemctl status mgetty@ttyUSB0.service</code>.</p></li><li><p>Examine logs: <code>sudo tail -f /var/log/syslog</code> and <code>sudo tail -f /var/log/auth.log</code>.</p></li><li><p>Ensure <code>init-chat</code> string in <code>mgetty.config</code> is correct (<code>ATZ OK</code>).</p></li><li><p>Test modem with <code>minicom -D /dev/ttyUSB0 -b 115200</code> (type <code>AT</code> then Enter, expect <code>OK</code>).</p></li></ul></li><li><p><strong>"Incorrect Password" / Authentication Failure:</strong></p><ul><li><p><strong>Most common:</strong> Mismatch in username, password, or server hostname in <code>/etc/ppp/pap-secrets</code>. Ensure case-sensitivity and correct hostname.</p></li><li><p><strong>Authentication Protocol:</strong> Confirm client is set to PAP, matching <code>+pap</code> in <code>options.ttyUSB0</code>.</p></li><li><p>Check logs: <code>sudo tail -f /var/log/syslog | grep pppd</code> (the <code>show-password</code> option in <code>options.ttyUSB0</code> helps here).</p></li></ul></li><li><p><strong>No Internet Access for Client:</strong></p><ul><li><p>Verify <code>net.ipv4.ip_forward=1</code> in <code>/etc/sysctl.conf</code> and applied (<code>sudo sysctl -p</code>).</p></li><li><p>Confirm <code>iptables</code> <code>POSTROUTING</code> (masquerade) and <code>FORWARD</code> rules are correct and saved (<code>sudo netfilter-persistent save</code>). Check your external interface name (<code>enp9s0</code> or <code>eth0</code>/<code>wlan0</code>).</p></li><li><p>Ensure <code>ms-dns</code> lines are in <code>options.ttyUSB0</code>.</p></li></ul></li><li><p><strong><code>ppp0: No such device exists</code> for <code>tcpdump</code>:</strong> The <code>ppp0</code> interface only appears when a client is actively connected via dial-up. Connect the client first, then run <code>tcpdump</code>.</p></li></ul><h2>7. Security Considerations</h2><ul><li><p><strong>Strong Passwords:</strong> Always use long, complex, and unique passwords for your dial-up users in <code>pap-secrets</code>.</p></li><li><p><strong>Firewall:</strong> Be aware of your system's firewall (e.g., <code>ufw</code>) rules. While <code>iptables</code> configures the necessary forwarding, ensure no other rules are inadvertently blocking traffic.</p></li><li><p><strong>Limited Access:</strong> Only create accounts for necessary users.</p></li><li><p><strong>Monitor Logs:</strong> Regularly check <code>/var/log/syslog</code> and <code>/var/log/auth.log</code> for any suspicious connection attempts or activities.</p></li><li><p><strong><code>show-password</code>:</strong> Remember to remove <code>show-password</code> from <code>/etc/ppp/options.ttyUSB0</code> once debugging is complete, as it exposes passwords in plaintext in your logs.</p></li></ul></div>
