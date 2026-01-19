# TP 1

## script 

[tp1.sh](tp1.sh)

## cron

```
*/5 * * * * /usr/bin/flock -n /tmp/system-check.cron.lock /home/mael/check.sh >> /var/log/system-check.log 2>&1
```

## systemd timer


/etc/systemd/system/system-check.service
```
[Unit]
Description=Script de monitoring systeme (Check CPU/RAM/Disk)

[Service]
Type=oneshot
ExecStart=/opt/scripts/system-check.sh
```

/etc/systemd/system/system-check.timer
```
[Unit]
Description=Lance le monitoring toutes les 5 minutes

[Timer]
# Au démarrage + 5min
OnBootSec=5min
# Calendrier : toutes les 5 minutes (00:05, 00:10...)
OnCalendar=*:0/5
# Délai aléatoire de 60s pour éviter que tous les serveurs se lancent à la milliseconde près (Thundering herd problem)
RandomizedDelaySec=60
    # Persistance : Si la machine était éteinte à l'heure prévue, rattrape le tir au démarrage
Persistent=true

[Install]
WantedBy=timers.target
```