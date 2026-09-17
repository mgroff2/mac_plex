#!/bin/bash

# Back up the things that are painful to recreate: app configuration, Plex's
# library database, Traefik's certificates, the .env file and the nightly
# database dumps. Media files are NOT included - they are far too large and
# should be mirrored separately.
#
# Nothing is stopped: containers keep running. Database consistency comes from
# scripts/backup-databases.sh (run it first, or let the 2:00 AM cron job do it),
# because dumps are consistent snapshots while a copied live database file is not.
#
# Usage: ./backup.sh [--dry-run] [--only name1,name2]
#   names: docker-config, arr-config, db-dumps, plex, traefik, secrets
#
# Deliberately excluded: media files, NZBGet downloads, Ollama models, *arr
# MediaCover artwork, logs and caches - all large and re-downloadable or
# regenerable. Plex's Metadata/Media folders are excluded for the same reason;
# its library database is covered by Plex's own scheduled backups.
#
# Set BACKUP_DIR in docker/.env (ideally on a different physical volume).

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/docker/.env"
LOG_FILE="${BACKUP_LOG:-/tmp/plex_backup.log}"

RSYNC=$(command -v rsync)
DRY_RUN=false
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --only) ONLY="$2"; shift ;;
        *) echo "Usage: $0 [--dry-run] [--only docker-config,arr-config,db-dumps,plex,traefik,secrets]"; exit 1 ;;
    esac
    shift
done

# Interactive runs echo to the terminal too; under cron stdout is usually
# redirected to the same log file, so only append once.
log() {
    local line="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    if [ -t 1 ]; then echo "$line" | tee -a "$LOG_FILE"; else echo "$line" >> "$LOG_FILE"; fi
}

get_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | sed -E "s/^['\"]//; s/['\"]$//"; }

# Ping an Uptime Kuma push monitor so a job that stops running is noticed.
# Set the URL in docker/.env; without it this does nothing.
heartbeat() {
    local url status msg
    url=$(get_env UPTIME_PUSH_CONFIG_BACKUP)
    [ -n "$url" ] || return 0
    status="$1"; msg="$2"
    curl -fsS -m 10 --get --data-urlencode "status=$status" --data-urlencode "msg=$msg" "$url" >/dev/null 2>&1 || true
}

[ -f "$ENV_FILE" ] || { log "ERROR: $ENV_FILE not found"; exit 1; }

DATA_DIR=$(get_env DATA_DIR)
ARR_DATA_DIR=$(get_env ARR_DATA_DIR); ARR_DATA_DIR="${ARR_DATA_DIR:-$DATA_DIR}"
DB_BACKUP_DIR=$(get_env DB_BACKUP_DIR); DB_BACKUP_DIR="${DB_BACKUP_DIR:-$DATA_DIR/db-backups}"
BACKUP_DIR="${BACKUP_DIR:-$(get_env BACKUP_DIR)}"   # env var wins, for testing
PLEX_APP_DIR="$HOME/Library/Application Support/Plex Media Server"

if [ -z "$BACKUP_DIR" ]; then
    log "ERROR: BACKUP_DIR is not set in $ENV_FILE - point it at your backup volume, e.g. BACKUP_DIR=/Volumes/Backup/mac_plex"
    exit 1
fi
if [ ! -d "$(dirname "$BACKUP_DIR")" ]; then
    log "ERROR: $(dirname "$BACKUP_DIR") does not exist - is the backup volume connected?"
    exit 1
fi

# name|source|destination subdir|extra rsync excludes (comma-separated)
JOBS=(
    "docker-config|$DATA_DIR|docker-data|nzbget/downloads,nzbget/intermediate,db-backups,ollama,MediaCover,logs,*.log,Cache"
    "arr-config|$ARR_DATA_DIR|arr-data|MediaCover,logs,*.log,Cache"
    "db-dumps|$DB_BACKUP_DIR|db-dumps|"
    "plex|$PLEX_APP_DIR|plex-app-support|Cache,Metadata,Media,Updates,Codecs,Crash Reports,Diagnostics,Logs"
    "traefik|$PROJECT_DIR/traefik|traefik|"
    "secrets|$ENV_FILE|secrets|"
)

failed=0
copied=0
$DRY_RUN && log "DRY RUN - no files will be written"
log "Backup destination: $BACKUP_DIR"

for job in "${JOBS[@]}"; do
    IFS='|' read -r name src dst excludes <<< "$job"
    [ -n "$ONLY" ] && [[ ",$ONLY," != *",$name,"* ]] && continue
    if [ ! -e "$src" ]; then
        log "SKIP $name: $src does not exist"
        continue
    fi

    opts=(-a --delete --human-readable --stats)
    $DRY_RUN && opts+=(-n)
    # Plex's own scheduled database backups are kept; its live .db files are not
    # consistent while Plex runs, so rely on those dumps for restores.
    [ "$name" = "plex" ] && opts+=(--exclude='*.db-wal' --exclude='*.db-shm')
    if [ -n "$excludes" ]; then
        IFS=',' read -ra ex <<< "$excludes"
        for e in "${ex[@]}"; do opts+=(--exclude="$e"); done
    fi

    target="$BACKUP_DIR/$dst"
    $DRY_RUN || mkdir -p "$target"
    src_arg="$src"; [ -d "$src" ] && src_arg="$src/"

    out=$("$RSYNC" "${opts[@]}" "$src_arg" "$target/" 2>&1)
    rc=$?
    # 24 = "some files vanished before they could be transferred"; normal for
    # live app data (logs rotating, databases checkpointing) and not a failure.
    if [ $rc -eq 0 ] || [ $rc -eq 24 ]; then
        size=$(echo "$out" | awk -F': ' '/Total transferred file size/ {print $2}')
        files=$(echo "$out" | awk -F': ' '/Number of regular files transferred/ {print $2}')
        log "OK   $name -> $dst (${files:-0} files, ${size:-0} transferred)$([ $rc -eq 24 ] && echo '  [some files changed during copy]')"
        copied=$((copied + 1))
    else
        log "FAIL $name: $(echo "$out" | tail -2 | tr '\n' ' ')"
        failed=1
    fi
done

# The .env file holds credentials - keep the copy unreadable by other users
if ! $DRY_RUN && [ -f "$BACKUP_DIR/secrets/.env" ]; then
    chmod 700 "$BACKUP_DIR/secrets"; chmod 600 "$BACKUP_DIR/secrets/.env"
fi

$DRY_RUN || log "Backup size on disk: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
if [ "$failed" -eq 0 ]; then
    log "Backup complete ($copied sets)"
    $DRY_RUN || heartbeat up "$copied sets copied"
else
    log "Backup finished WITH ERRORS"
    $DRY_RUN || heartbeat down "one or more sets failed"
fi
exit $failed
