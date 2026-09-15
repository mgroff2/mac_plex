#!/bin/bash

# Update running Docker containers to their latest images.
# Replaces Watchtower (archived upstream in December 2025).
#
# Only services that are currently running are updated, so services you have
# intentionally left stopped are never started. Services listed in
# AUTO_UPDATE_EXCLUDE (docker/.env, comma-separated) are skipped.
#
# Usage: ./update-containers.sh [--dry-run]
# Scheduled nightly by install.sh via cron; logs to /tmp/docker-update.log

set -uo pipefail

# cron runs with a minimal PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$PROJECT_DIR/docker"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cd "$COMPOSE_DIR" || { log "ERROR: compose directory not found: $COMPOSE_DIR"; exit 1; }

if ! docker info >/dev/null 2>&1; then
    log "ERROR: Docker is not running, skipping update"
    exit 1
fi

# Databases are excluded by default: unattended major-version upgrades can break data
EXCLUDE=$(grep -E '^AUTO_UPDATE_EXCLUDE=' .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "'\" ")
EXCLUDE="${EXCLUDE:-mysql,postgres}"

services=()
for service in $(docker compose ps --services --status running); do
    if [[ ",$EXCLUDE," == *",$service,"* ]]; then
        log "Skipping excluded service: $service"
    else
        services+=("$service")
    fi
done

if [ ${#services[@]} -eq 0 ]; then
    log "No running services to update"
    exit 0
fi

log "Updating services: ${services[*]}"

if [ "$DRY_RUN" = true ]; then
    docker compose --dry-run pull "${services[@]}"
    docker compose --dry-run up -d --no-deps "${services[@]}"
    log "Dry run complete, no changes made"
    exit 0
fi

# --ignore-pull-failures: one unreachable registry shouldn't block the rest
if ! docker compose pull --quiet --ignore-pull-failures "${services[@]}"; then
    log "WARNING: some images failed to pull"
fi

# --no-deps: never start or recreate dependencies (e.g. excluded databases).
# Compose only recreates containers whose image or configuration changed.
if docker compose up -d --no-deps "${services[@]}"; then
    log "Update complete"
else
    log "ERROR: failed to recreate one or more services"
    exit 1
fi
