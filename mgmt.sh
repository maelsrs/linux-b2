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

mkdir root/ansible
sudo apt install ansible
sudo bash -c "cat > /root/ansible/inventory.ini" <<EOF
[servers]
web ansible_host=10.5.2.10 ansible_user=mael
EOF
sudo ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""
sudo ssh-copy-id -i /root/.ssh/id_ed25519.pub mael@10.5.2.10
mkdir -p vars templates
sudo bash -c "cat > /root/ansible/vars/main.yml" <<EOF
http_port: 80
server_name: "_" 
doc_root: "/var/www/mysite"
page_title: "Bienvenue sur mon Serveur Ansible"
page_content: "Ce serveur a été configuré automatiquement par Ansible !"
EOF

sudo bash -c "cat > /root/ansible/templates/index.html.j2" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>{{ page_title }}</title>
</head>
<body>
    <h1>{{ page_title }}</h1>
    <p>{{ page_content }}</p>
    <small>Déployé sur l'hôte : {{ ansible_hostname }}</small>
</body>
</html>
EOF

sudo bash -c "cat > /root/ansible/templates/myapp.conf.j2" <<EOF
server {
    listen {{ http_port }};
    server_name {{ server_name }};
    root {{ doc_root }};
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF


sudo bash -c "cat > /root/ansible/webserver.yml" <<EOF
---
- name: Installation et configuration du serveur Web
  hosts: webservers  # Le nom du groupe dans ton inventory.ini
  become: yes        # "sudo" automatique pour toutes les tâches
  vars_files:
    - vars/main.yml

  tasks:
    - name: 1. Mettre à jour le cache APT
      apt:
        update_cache: yes
        cache_valid_time: 3600 

    - name: 2. Installer Nginx
      apt:
        name: nginx
        state: present

    - name: 3. Créer le dossier du site
      file:
        path: "{{ doc_root }}"
        state: directory
        mode: '0755'
        owner: www-data
        group: www-data

    - name: 4. Déployer la page HTML (depuis template)
      template:
        src: templates/index.html.j2
        dest: "{{ doc_root }}/index.html"
        owner: www-data
        group: www-data

    - name: 5. Configurer le VirtualHost Nginx (depuis template)
      template:
        src: templates/myapp.conf.j2
        dest: /etc/nginx/sites-available/mysite.conf
      notify: Restart Nginx  # Déclenche le handler si le fichier change

    - name: 6. Activer le site (Lien symbolique)
      file:
        src: /etc/nginx/sites-available/mysite.conf
        dest: /etc/nginx/sites-enabled/mysite.conf
        state: link
      notify: Restart Nginx

    - name: 7. Supprimer la config Nginx par défaut (Optionnel)
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent
      notify: Restart Nginx

    - name: 8. S'assurer que Nginx est démarré et activé au boot
      service:
        name: nginx
        state: started
        enabled: yes

    - name: 9. Ouvrir le port 80 (UFW)
      ufw:
        rule: allow
        port: "{{ http_port }}"
        proto: tcp

  # Les handlers ne se lancent que si une tâche les notifie (et une seule fois à la fin)
  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
EOF

ansible-playbook -i inventory.ini webserver.yml

