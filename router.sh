#!/bin/bash

# 1. VARIABLES
export WAN_IF="enp0s3"     # Internet (NAT/Bridge)
export LAN_IF="enp0s8"     # VLAN 10 (Trust)
export DMZ_IF="enp0s9"     # VLAN 20 (Public)
export USER_IF="enp0s10"   # VLAN 30 (Employés)
export ADMIN_IF="enp0s16"  # VLAN 99 (Gestion)

# 2. SSH
sudo apt update -y
sudo apt install isc-dhcp-server -y

sudo systemctl enable ssh

mkdir -p ~/.ssh
if ! grep -q "maaaeeel" ~/.ssh/authorized_keys; then
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbK2twpupMT1+Io4afHLnqJWekmbiIUA5E5R4rNLRBs maaaeeel" >> ~/.ssh/authorized_keys
fi
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# 3. NETWORK
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/^#\s*net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo bash -c "cat > /etc/netplan/00-installer-config.yaml" <<EOF
network:
  ethernets:
    $WAN_IF:
      dhcp4: true
    $LAN_IF:
      dhcp4: no
      addresses: [10.5.1.2/24]
    $DMZ_IF:
      dhcp4: no
      addresses: [10.5.2.2/24]
    $USER_IF:
      dhcp4: no
      addresses: [10.5.3.2/24]
    $ADMIN_IF:
      dhcp4: no
      addresses: [10.5.99.2/24]
  version: 2
EOF

sudo netplan apply

# 4. DHCP
sudo sed -i 's/^INTERFACESv4=.*/INTERFACESv4="'$LAN_IF' '$DMZ_IF' '$USER_IF' '$ADMIN_IF'"/' /etc/default/isc-dhcp-server

[ ! -f /etc/dhcp/dhcpd.conf.bak ] && sudo mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak

sudo bash -c "cat > /etc/dhcp/dhcpd.conf" <<EOF
option domain-name "main.lan";
option domain-name-servers 1.1.1.1, 1.0.0.1;

default-lease-time 600;
max-lease-time 7200;
authoritative;

# ZONE LAN (VLAN 10) - Servers & Mgmt
subnet 10.5.1.0 netmask 255.255.255.0 {
    range 10.5.1.50 10.5.1.100;
    option routers 10.5.1.2;
    option broadcast-address 10.5.1.255;
}

# ZONE DMZ (VLAN 20) - Web & VPN
subnet 10.5.2.0 netmask 255.255.255.0 {
    range 10.5.2.50 10.5.2.100;
    option routers 10.5.2.2;
    option broadcast-address 10.5.2.255;
}

# ZONE USER (VLAN 30) - Employés
subnet 10.5.3.0 netmask 255.255.255.0 {
    range 10.5.3.50 10.5.3.100;
    option routers 10.5.3.2;
    option broadcast-address 10.5.3.255;
}

# ZONE ADMIN (VLAN 99) - Gestion
subnet 10.5.99.0 netmask 255.255.255.0 {
    range 10.5.99.50 10.5.99.100;
    option routers 10.5.99.2;
    option broadcast-address 10.5.99.255;
}
EOF

sudo systemctl restart isc-dhcp-server

# 5. IPTABLES
sudo bash -c "cat > /etc/iptables_rules.sh" <<EOF
#!/bin/bash

WAN="$WAN_IF"
LAN="$LAN_IF"
DMZ="$DMZ_IF"
USER="$USER_IF"
ADMIN="$ADMIN_IF"

# 1. RESET COMPLET
iptables -F
iptables -t nat -F
iptables -X

# 2. POLICIES (On ferme tout)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 3. INPUT (Vers le routeur)
# Localhost
iptables -A INPUT -i lo -j ACCEPT
# Connexions établies
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# DHCP & DNS (UDP) autorisé pour tout le monde en interne
iptables -A INPUT -p udp --dport 67:68 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
# ICMP (Ping) autorisé pour le debug
iptables -A INPUT -p icmp -j ACCEPT

# SSH : AUTORISÉ UNIQUEMENT DEPUIS ADMIN (VLAN 99)
iptables -A INPUT -i \$ADMIN -p tcp --dport 22 -j ACCEPT
# Enable lan SSH access if needed
iptables -A INPUT -i \$LAN -p tcp --dport 22 -j ACCEPT

# 4. FORWARD (Traversée du routeur)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# A. Accès INTERNET pour tout le monde
iptables -A FORWARD -i \$LAN -o \$WAN -j ACCEPT
iptables -A FORWARD -i \$DMZ -o \$WAN -j ACCEPT
iptables -A FORWARD -i \$USER -o \$WAN -j ACCEPT
iptables -A FORWARD -i \$ADMIN -o \$WAN -j ACCEPT

# B. ADMIN a accès à TOUT (LAN, DMZ, USER)
iptables -A FORWARD -i \$ADMIN -o \$LAN -j ACCEPT
iptables -A FORWARD -i \$ADMIN -o \$DMZ -j ACCEPT
iptables -A FORWARD -i \$ADMIN -o \$USER -j ACCEPT

# C. USER a accès au WEB (DMZ ports 80/443)
iptables -A FORWARD -i \$USER -o \$DMZ -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i \$USER -o \$DMZ -p tcp --dport 443 -j ACCEPT

# D. MGMT (LAN) a accès à DMZ (Monitoring)
iptables -A FORWARD -i \$LAN -o \$DMZ -j ACCEPT

# 5. NAT (Masquerade)
iptables -t nat -A POSTROUTING -o \$WAN -j MASQUERADE
EOF

sudo chmod +x /etc/iptables_rules.sh
sudo /etc/iptables_rules.sh
