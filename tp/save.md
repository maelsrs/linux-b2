#!/bin/bash


## Exercice 1

/root/backup.sh
```sh
rsync -a --exclude '*.log' --exclude 'cache/' /home /var/www /backup/$(date +%F) || echo "Echec Backup" | mail -s "Alerte" admin@toi.com


find /backup/* -maxdepth 0 -type d -mtime +7 -exec rm -rf {} \;
```

Cron
```
crontab -e
0 3 * * * /root/backup.sh
```

## Exercice 2

```
#!/bin/bash

mkdir -p /backup/mysql

mysqldump -u root testdb | gzip > /backup/mysql/db_$(date +%F).sql.gz

find /backup/mysql -name "*.gz" -mtime +30 -delete
```

Test

```
root@mael-vb:/backup/mysql# mysql -u root -e "DROP DATABASE testdb;"
root@mael-vb:/backup/mysql# mysql -u root -e "CREATE DATABASE testdb;"
root@mael-vb:/backup/mysql# zcat /backup/mysql/db_2025-12-04.sql.gz | mysql -u root testdb
root@mael-vb:/backup/mysql# mysql -u root -D testdb -e "SELECT * FROM clients;"
+------+-------+
| id   | nom   |
+------+-------+
|    1 | Mario |
+------+-------+
```

## Exercice 3

```
apt install borgbackup -y
export BORG_REPO=/backup/borg_repo
export BORG_PASSPHRASE='passwordhihi'
borg init --encryption=repokey
```

Test

```
echo "Données du jour 1" > mon_fichier.txt
borg create ::jour1 mon_fichier.txt

echo "Données du jour 2" >> mon_fichier.txt
borg create ::jour2 mon_fichier.txt

echo "Données du jour 3" >> mon_fichier.txt
borg create ::jour3 mon_fichier.txt

root@mael-vb:/backup/mysql# borg info ::jour3
Archive name: jour3
Archive fingerprint: 3db553b569a51dc1987d642e63b63ed1e51a1f4962bacf7aab9b61dd652000d1
Comment:
Hostname: mael-vb
Username: root
Time (start): Thu, 2025-12-04 11:06:15
Time (end): Thu, 2025-12-04 11:06:15
Duration: 0.01 seconds
Number of files: 1
Command line: /usr/bin/borg create ::jour3 mon_fichier.txt
Utilization of maximum supported archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                   57 B                 76 B                784 B
All archives:                  114 B                210 B              2.33 kB

                       Unique chunks         Total chunks
Chunk index:                       9                    9


rm mon_fichier.txt
borg extract ::jour1    
root@mael-vb:/backup/mysql# cat mon_fichier.txt
Données du jour 1
```