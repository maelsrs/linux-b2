# base
export WAN_IF="enp0s3"
export LAN_IF="enp0s8" 

systemctl enable ssh
sudo apt update -y
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbK2twpupMT1+Io4afHLnqJWekmbiIUA5E5R4rNLRBs maaaeeel" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# network
sudo bash -c "cat > /etc/netplan/00-installer-config.yaml" <<EOF
network:
  ethernets:
    $LAN_IF:
      dhcp4: no
      addresses:
        - 10.5.1.2/24
  version: 2
EOF

sudo netplan apply
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/^#\s*net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

sudo apt install isc-dhcp-server -y
sudo sed -i 's/^INTERFACESv4=.*/INTERFACESv4="'$LAN_IF'"/' /etc/default/isc-dhcp-server
sudo mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
sudo bash -c "cat > /etc/dhcp/dhcpd.conf" <<EOF
option domain-name "b2.linux";
option domain-name-servers 8.8.8.8, 8.8.4.4;

default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 10.5.1.0 netmask 255.255.255.0 {
    range 10.5.1.10 10.5.1.100;
    option routers 10.5.1.2;
    option broadcast-address 10.5.1.255;
}
EOF
sudo systemctl restart isc-dhcp-server

# firewall
sudo bash -c "cat > /tmp/iptables_rules.sh" <<EOF
#!/bin/bash

# Reset
iptables -F
iptables -t nat -F

# Policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# LAN Access (DHCP/DNS traffic from LAN)
iptables -A INPUT -i $LAN_IF -j ACCEPT

# Forwarding (LAN -> WAN)
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# NAT (Masquerade)
iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE
EOF

sudo chmod +x /tmp/iptables_rules.sh
sudo /tmp/iptables_rules.sh
rm -f /tmp/iptables_rules.sh