#!/bin/bash
# rclone-gdrive-watch.sh — sync local → GDrive triggered by inotify
# Usage: rclone-gdrive-watch.sh <local_dir> <remote:path>

LOCAL="${1:-/data/GoogleDrive}"
REMOTE="${2:-gdrive:}"
DEBOUNCE=5
LOGFILE="/var/log/rclone-sync.log"

echo "[$(date)] Starting watch: $LOCAL → $REMOTE" | tee -a "$LOGFILE"

inotifywait -m -r -e modify,create,delete,move "$LOCAL" 2>/dev/null |
while read -r dir event file; do
    sleep "$DEBOUNCE"
    while read -r -t 0.1 _; do :; done
    rclone sync "$LOCAL" "$REMOTE" \
        --fast-list \
        --transfers 4 \
        --log-level INFO \
        --log-file "$LOGFILE"
    echo "[$(date)] Sync $LOCAL → $REMOTE done" | tee -a "$LOGFILE"
done
