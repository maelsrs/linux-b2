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
[webservers]
web ansible_host=10.5.2.10 ansible_user=root

[other]
router ansible_host=10.5.1.2 ansible_user=root
database ansible_host=10.5.1.20 ansible_user=root
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

mkdir -p /root/supervision
cd /root/supervision

sudo bash -c "cat > /root/supervision/prometheus.yml" <<'PROM_EOF'
global:
  scrape_interval: 10s
  evaluation_interval: 10s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          nodename: 'mgmt'
      - targets: ['10.5.2.10:9100']
        labels:
          nodename: 'app'
      - targets: ['10.5.1.2:9100']
        labels:
          nodename: 'router'
rule_files:
  - "alert.rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
PROM_EOF

sudo bash -c "cat > /root/supervision/alert.rules.yml" <<'ALERT_EOF'
groups:
  - name: test_alerts
    rules:
      - alert: HighMemoryUsage
        expr: (1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes) * 100 > 50
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Mémoire élevée"
          description: "Utilisation mémoire à {{ $value }}%"

      - alert: InstanceDown
        expr: up == 0
        for: 5s
        labels:
          severity: critical
        annotations:
          summary: "Instance down"
ALERT_EOF

sudo bash -c "cat > /root/supervision/alertmanager.yml" <<'ALERTM_EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'nodename']
  group_wait: 3s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'discord_webhook'

receivers:
  - name: 'discord_webhook'
    webhook_configs:
      - url: 'http://alertmanager-discord:9094'
        send_resolved: true
ALERTM_EOF

sudo bash -c "cat > /root/supervision/docker-compose.yml" <<'DOCKER_EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert.rules.yml:/etc/prometheus/alert.rules.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123

  node-exporter:
    image: quay.io/prometheus/node-exporter
    ports:
      - "9100:9100"
    pid: host
    volumes:
      - /:/host:ro
    command:
      - '--path.rootfs=/host'

  alertmanager:
    image: prom/alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml

  alertmanager-discord:
    image: benjojo/alertmanager-discord
    ports:
      - "9094:9094"
    environment:
      - DISCORD_WEBHOOK=https://discord.com/api/webhooks/1465010726530711827/2RG6ntpPbza9vaW4LW9eoyKfjI2D2j9qQ919Hy0Cqv3sf0TeFePSBHQcOUf4KJPoez8-
DOCKER_EOF

cd /root/supervision
docker-compose up -d

export ANSIBLE_HOST_KEY_CHECKING=False
sudo bash -c "cat > /root/ansible/install-node-exporter.yml" <<'NODEEXP_EOF'
---
- name: Installation de Node Exporter (Docker) sur tous les hosts
  hosts: all
  become: yes

  tasks:
    - name: Mettre à jour le cache APT
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Installer Docker et les dépendances Python pour Ansible
      apt:
        name:
          - docker.io
          - python3-docker  # INDISPENSABLE pour utiliser le module docker_container
          - python3-pip
        state: present

    - name: S'assurer que le service Docker est démarré et activé
      service:
        name: docker
        state: started
        enabled: yes

    - name: Créer le dossier node-exporter (optionnel mais propre)
      file:
        path: /opt/node-exporter
        state: directory
        mode: '0755'

    - name: Lancer le conteneur node-exporter
      docker_container:
        name: node-exporter
        image: quay.io/prometheus/node-exporter:latest
        state: started
        restart_policy: always
        ports:
          - "9100:9100"
        pid_mode: host
        volumes:
          - /:/host:ro,rslave
        command: 
          - '--path.rootfs=/host'
NODEEXP_EOF

cd /root/ansible
ansible-playbook -i inventory.ini install-node-exporter.yml