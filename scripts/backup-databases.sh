#!/bin/bash

# Dump the PostgreSQL and MySQL databases used by the stack.
#
# Sonarr, Radarr and n8n keep everything in PostgreSQL and Ombi in MySQL, and
# none of those apps back the databases up themselves - their own backup
# features only cover config files. Dumps land on DB_BACKUP_DIR (a media volume
# by default) so they are picked up by array/offsite backups rather than only
# living on the internal SSD with the databases.
#
# Usage: ./backup-databases.sh [--dry-run]
# Scheduled nightly by install.sh via cron; logs to /tmp/db-backup.log

set -uo pipefail

# cron runs with a minimal PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
export DOCKER_CLI_HINTS=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/docker/.env"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

get_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | sed -E "s/^['\"]//; s/['\"]$//"; }

# Ping an Uptime Kuma push monitor so a job that stops running is noticed.
# Set the URL in docker/.env; without it this does nothing.
heartbeat() {
    local url status msg
    url=$(get_env UPTIME_PUSH_DB_BACKUP)
    [ -n "$url" ] || return 0
    status="$1"; msg="$2"
    curl -fsS -m 10 --get --data-urlencode "status=$status" --data-urlencode "msg=$msg" "$url" >/dev/null 2>&1 || true
}

DATA_DIR=$(get_env DATA_DIR)
BACKUP_DIR=$(get_env DB_BACKUP_DIR); BACKUP_DIR="${BACKUP_DIR:-$DATA_DIR/db-backups}"
KEEP_DAYS=$(get_env DB_BACKUP_KEEP_DAYS); KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP=$(date +%Y%m%d-%H%M%S)
failed=0

if ! docker info >/dev/null 2>&1; then
    log "ERROR: Docker is not running, skipping database backup"
    exit 1
fi

if $DRY_RUN; then
    log "DRY RUN: would write dumps to $BACKUP_DIR (keeping $KEEP_DAYS days)"
    docker ps --format '{{.Names}}' | grep -qx postgres && log "  postgres: $(docker exec postgres psql -U postgres -Atc "select string_agg(datname,' ') from pg_database where not datistemplate and datname <> 'postgres'" 2>/dev/null)"
    docker ps --format '{{.Names}}' | grep -qx mysql && log "  mysql: all databases"
    exit 0
fi

mkdir -p "$BACKUP_DIR/postgres" "$BACKUP_DIR/mysql" || { log "ERROR: cannot create $BACKUP_DIR"; exit 1; }
chmod 700 "$BACKUP_DIR" "$BACKUP_DIR/postgres" "$BACKUP_DIR/mysql"

# --- PostgreSQL: roles/globals once, then one custom-format dump per database
if docker ps --format '{{.Names}}' | grep -qx postgres; then
    globals="$BACKUP_DIR/postgres/globals-$STAMP.sql.gz"
    if docker exec postgres pg_dumpall -U postgres --globals-only 2>/dev/null | gzip > "$globals"; then
        chmod 600 "$globals"; log "postgres globals -> $(basename "$globals") ($(du -h "$globals" | cut -f1))"
    else
        log "ERROR: pg_dumpall --globals-only failed"; rm -f "$globals"; failed=1
    fi

    dbs=$(docker exec postgres psql -U postgres -Atc "select datname from pg_database where not datistemplate and datname <> 'postgres'" 2>/dev/null)
    for db in $dbs; do
        out="$BACKUP_DIR/postgres/${db}-$STAMP.dump"
        if docker exec postgres pg_dump -U postgres -Fc "$db" > "$out" 2>/dev/null && [ -s "$out" ]; then
            chmod 600 "$out"; log "postgres $db -> $(basename "$out") ($(du -h "$out" | cut -f1))"
        else
            log "ERROR: pg_dump failed for $db"; rm -f "$out"; failed=1
        fi
    done
else
    log "postgres container not running, skipped"
fi

# --- MySQL: single dump of everything (Ombi, plus the archived Bookstack's database)
if docker ps --format '{{.Names}}' | grep -qx mysql; then
    out="$BACKUP_DIR/mysql/all-databases-$STAMP.sql.gz"
    if docker exec -e MYSQL_PWD="$(get_env MYSQL_ROOT_PASSWORD)" mysql \
        mysqldump -u root --all-databases --single-transaction --quick --routines --events 2>/dev/null | gzip > "$out" && [ -s "$out" ]; then
        chmod 600 "$out"; log "mysql all databases -> $(basename "$out") ($(du -h "$out" | cut -f1))"
    else
        log "ERROR: mysqldump failed"; rm -f "$out"; failed=1
    fi
else
    log "mysql container not running, skipped"
fi

# --- retention
deleted=$(find "$BACKUP_DIR" -type f \( -name '*.dump' -o -name '*.sql.gz' \) -mtime +"$KEEP_DAYS" -print -delete | wc -l | tr -d ' ')
[ "$deleted" -gt 0 ] && log "removed $deleted dump(s) older than $KEEP_DAYS days"

log "total on disk: $(du -sh "$BACKUP_DIR" | cut -f1)"
if [ "$failed" -eq 0 ]; then
    log "Database backup complete"
    heartbeat up "dumps ok"
else
    log "Database backup finished WITH ERRORS"
    heartbeat down "one or more dumps failed"
fi
exit $failed
