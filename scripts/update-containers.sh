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
# Suppress Docker Desktop "What's next" hints in the nightly log
export DOCKER_CLI_HINTS=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$PROJECT_DIR/docker"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_env() { grep -E "^$1=" "$COMPOSE_DIR/.env" 2>/dev/null | tail -1 | cut -d= -f2- | sed -E "s/^['\"]//; s/['\"]$//"; }
# Ping an Uptime Kuma push monitor so a job that stops running is noticed.
# Set the URL in docker/.env; without it this does nothing.
heartbeat() {
    local url status msg
    url=$(get_env UPTIME_PUSH_CONTAINER_UPDATE)
    [ -n "$url" ] || return 0
    status="$1"; msg="$2"
    curl -fsS -m 10 --get --data-urlencode "status=$status" --data-urlencode "msg=$msg" "$url" >/dev/null 2>&1 || true
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
    log "DRY RUN: output below is simulated by Docker Compose - nothing is pulled, recreated or started"
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
docker compose up -d --no-deps "${services[@]}"
rc=$?

# Docker sometimes fails to stop a container ("did not receive an exit event"),
# which aborts compose and leaves services down. Recover rather than alerting and
# walking away: a service left stopped here stays stopped until someone notices,
# and the nightly prune then deletes the container and its image.
missing=()
for service in "${services[@]}"; do
    docker compose ps --services --status running | grep -qx "$service" || missing+=("$service")
done

if [ ${#missing[@]} -gt 0 ]; then
    log "WARNING: not running after update: ${missing[*]} - retrying"
    for service in "${missing[@]}"; do
        # Force-remove a stuck container, then let compose recreate it
        cid=$(docker compose ps -aq "$service" 2>/dev/null)
        [ -n "$cid" ] && docker rm -f "$cid" >/dev/null 2>&1
        docker compose up -d --no-deps "$service" >/dev/null 2>&1
    done
    still_down=()
    for service in "${missing[@]}"; do
        docker compose ps --services --status running | grep -qx "$service" || still_down+=("$service")
    done
    if [ ${#still_down[@]} -gt 0 ]; then
        log "ERROR: still not running after retry: ${still_down[*]}"
        heartbeat down "still down after retry: ${still_down[*]}"
        exit 1
    fi
    log "Recovered after retry: ${missing[*]}"
    heartbeat up "${#services[@]} services checked, recovered ${missing[*]}"
    exit 0
fi

if [ $rc -ne 0 ]; then
    log "WARNING: compose reported an error but every service is running"
fi
log "Update complete"
heartbeat up "${#services[@]} services checked"
