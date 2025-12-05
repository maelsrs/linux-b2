#!/bin/bash

# Usage: ./restore.sh <date_full> <date_diff>
# Ex:    ./restore.sh 2023-10-22 2023-10-26

BACKUP_SERVER="mael@10.5.1.10"
DEST_DIR="/var/backups/vm-app"
RESTORE_LOCATION="/"

DATE_FULL=$1
DATE_DIFF=$2

if [ -z "$DATE_FULL" ]; then
    echo "Erreur: Il faut préciser la date du Full (ex: 2023-10-22)"
    exit 1
fi

echo "1. Récupération des archives depuis le serveur..."

mkdir -p /tmp/restore_work
cd /tmp/restore_work

scp $BACKUP_SERVER:$DEST_DIR/backup-full-$DATE_FULL.tar.gz .

if [ ! -z "$DATE_DIFF" ]; then
    scp $BACKUP_SERVER:$DEST_DIR/backup-diff-$DATE_DIFF.tar.gz .
fi

echo "2. Extraction du FULL..."
tar --extract --gzip --file=backup-full-$DATE_FULL.tar.gz --directory=$RESTORE_LOCATION

if [ ! -z "$DATE_DIFF" ]; then
    echo "3. Application du DIFF (Modifications depuis le Full)..."
    tar --extract --gzip --file=backup-diff-$DATE_DIFF.tar.gz --directory=$RESTORE_LOCATION
fi

echo "✅ Restauration terminée. Vérifie tes fichiers."
rm -rf /tmp/restore_work