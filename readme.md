| Machine | Zone / VLAN | IP Statique | Rôle & Services Hébergés |
| :--- | :--- | :--- | :--- |
| **VM-ROUTER** | **TRUNK** (Gateway) | `10.5.1.2` (LAN)<br>`10.5.2.2` (DMZ)<br>`10.5.3.2` (USER)<br>`10.5.99.2` (ADMIN) | • Routing Inter-VLAN<br>• Firewall (iptables)<br>• DHCP & DNS (Bind9) |
| **VM-APP** | DMZ (VLAN 20) | `10.5.2.10` | • Nginx (Reverse Proxy)<br>• Docker (App Web) |
| **VM-DATA** | LAN (VLAN 10) | `10.5.1.20` | • BDD |
| **VM-MGMT** | LAN (VLAN 10) | `10.5.1.10` | • Ansible (Automatisation)<br>• Backup (Rsync)<br>• Monitoring |
| **VM-USER** | USERS (VLAN 30) | `10.5.3.10` | • Client de test<br>• Accès Web restreint |
| **VM-ADMIN** | ADMIN (VLAN 99) | `10.5.99.10` | • Poste d'administration |


<!-- | **VM-VPN** | DMZ (VLAN 20) | `10.5.2.200` | • WireGuard (Point d'entrée unique)<br>• Accès SSH sécurisé | -->

"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifyvm "b2-main" --nic5 hostonly --hostonlyadapter5 "VirtualBox Host-Only Ethernet Adapter #5"
