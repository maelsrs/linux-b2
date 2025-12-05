#!/bin/bash

IFACE="enp0s3"  

sudo apt update
sudo apt install openssh-server -y
sudo systemctl enable ssh

mkdir -p ~/.ssh
if ! grep -q "maaaeeel" ~/.ssh/authorized_keys; then
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbK2twpupMT1+Io4afHLnqJWekmbiIUA5E5R4rNLRBs maaaeeel" >> ~/.ssh/authorized_keys
fi
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

sudo bash -c "cat > /etc/netplan/00-installer-config.yaml" <<EOF
network:
  ethernets:
    $IFACE:
      dhcp4: no
      addresses:
        - 10.5.3.10/24
      routes:
        - to: default
          via: 10.5.3.2
      nameservers:
        addresses: [1.1.1.1, 1.0.0.1]
  version: 2
EOF

sudo netplan apply
