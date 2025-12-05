#!/bin/bash

IFACE="enp0s3"  
sudo bash -c "cat > /etc/netplan/00-installer-config.yaml" <<EOF
network:
  ethernets:
    $IFACE:
      dhcp4: no
      addresses:
        - 10.5.1.10/24
      routes:
        - to: default
          via: 10.5.1.2
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
  version: 2
EOF

sudo netplan apply

sudo apt update
sudo apt install openssh-server -y
sudo systemctl enable ssh

mkdir -p ~/.ssh
if ! grep -q "maaaeeel" ~/.ssh/authorized_keys; then
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbK2twpupMT1+Io4afHLnqJWekmbiIUA5E5R4rNLRBs maaaeeel" >> ~/.ssh/authorized_keys
fi
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

sudo apt install -y curl git rsync software-properties-common

sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER

sudo mkdir -p /var/backups/vm-app
sudo chown root:root /var/backups/vm-app
sudo chmod 750 /var/backups/vm-app

sudo chown -R mael:mael /var/backups/vm-app
sudo chmod 750 /var/backups/vm-app

sudo docker run -d --restart=always -p 3001:3001 -v uptime-kuma:/app/data --name uptime-kuma louislam/uptime-kuma:1