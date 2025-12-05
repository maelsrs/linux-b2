#!/bin/bash

BACKUP_SERVER="mael@10.5.1.10"
DEST_DIR="/var/backups/vm-app"
LOCAL_SNAP_DIR="/var/cache/backup_snaps"
DATE=$(date +%F)
DAY_OF_WEEK=$(date +%u)

SOURCE_DIRS="/etc/nginx /var/www/html /etc/netplan"
SNAP_FILE="$LOCAL_SNAP_DIR/snapshot.snar"

mkdir -p $LOCAL_SNAP_DIR

if [ "$DAY_OF_WEEK" -eq 7 ]; then
    echo "--- DIMANCHE : Sauvegarde COMPLÈTE (Full) ---"
    TYPE="full"
    
    rm -f $SNAP_FILE
    
    ARCHIVE_NAME="backup-$TYPE-$DATE.tar.gz"
    
    tar --create --gzip --file=/tmp/$ARCHIVE_NAME \
        --listed-incremental=$SNAP_FILE \
        $SOURCE_DIRS 2> /dev/null

else
    echo "--- SEMAINE : Sauvegarde DIFFÉRENTIELLE (Diff) ---"
    TYPE="diff"
    
    if [ -f $SNAP_FILE ]; then
        cp $SNAP_FILE $SNAP_FILE.temp
        USE_SNAP=$SNAP_FILE.temp
    else
        echo "⚠️  Pas de snapshot trouvé, forçage d'un nouveau cycle..."
        TYPE="full-forced"
        USE_SNAP=$SNAP_FILE
    fi
    
    ARCHIVE_NAME="backup-$TYPE-$DATE.tar.gz"
    
    tar --create --gzip --file=/tmp/$ARCHIVE_NAME \
        --listed-incremental=$USE_SNAP \
        $SOURCE_DIRS 2> /dev/null
        
    [ -f $SNAP_FILE.temp ] && rm -f $SNAP_FILE.temp
fi

echo "--- Envoi vers le serveur de stockage ($BACKUP_SERVER) ---"

ssh $BACKUP_SERVER "mkdir -p $DEST_DIR" 2>/dev/null

rsync -avz --remove-source-files /tmp/$ARCHIVE_NAME $BACKUP_SERVER:$DEST_DIR/

if [ $? -eq 0 ]; then
    echo "✅ Sauvegarde $TYPE réussie : $ARCHIVE_NAME"
else
    echo "❌ Erreur lors du transfert Rsync"
    exit 1
fi