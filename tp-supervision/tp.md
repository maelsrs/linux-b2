## TP 1

## TP 2

```
mael@b2-mgmt:~$ journalctl -p err --since today --no-pager | \
awk '{print $5}' | \
cut -d: -f1 | \
sort | \
uniq -c | \
sort -rn
Journal file /var/log/journal/db6ed784a6ef4ecead2cbe5271512a06/user-1000@000645303354511d-5eef8df4bc8241d2.journal~ is truncated, ignoring file.
     10 kernel
      6 systemd[1]
      2 sudo[2126]
      2 sudo[2084]
```

Les erreurs kernel et systemctl