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
        - 10.5.2.10/24
      routes:
        - to: default
          via: 10.5.2.2
      nameservers:
        addresses: [1.1.1.1, 1.0.0.1]
  version: 2
EOF

sudo netplan apply

sudo apt install docker.io docker-compose nginx -y
sudo usermod -aG docker $USER
sudo systemctl enable nginx
sudo systemctl restart nginx

sudo docker run -d -p 9000:9000 --name=portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    portainer/portainer-ce:latest

sudo ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
sudo ssh-copy-id -i /root/.ssh/id_ed25519.pub mael@10.5.1.10

CRON_JOB="0 2 * * * /usr/local/bin/app_backup.sh >> /var/log/backup.log 2>&1"
(crontab -l 2>/dev/null | grep -F "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -