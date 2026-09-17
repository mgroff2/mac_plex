#!/bin/bash

# Check the S.M.A.R.T. health of every drive that reports it and raise an alert
# when one starts to fail. The media arrays are RAID 0 (AppleRAID stripes), so a
# single dead drive loses the whole array - early warning is the only defence.
#
# Drives in USB enclosures cannot report S.M.A.R.T. data on macOS (the USB-SATA
# bridge does not pass the commands through); they are counted and reported, but
# never treated as a failure. AppleRAID membership is checked for every drive, so
# a disk that dies or drops out is caught even without S.M.A.R.T.
#
# Usage: ./check-drive-health.sh [--quiet]
# Scheduled daily by install.sh via cron; logs to /tmp/drive-health.log
#
# Optional settings in docker/.env:
#   DRIVE_TEMP_WARN          warn above this temperature in Celsius (default 55;
#                            these Ultrastar drives are rated to 60 and sit at 42-48)
#   UPTIME_PUSH_DRIVE_HEALTH Uptime Kuma push URL to notify (up/down)

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/docker/.env"

QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

log() { $QUIET || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

get_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | sed -E "s/^['\"]//; s/['\"]$//"; }

heartbeat() {
    local url
    url=$(get_env UPTIME_PUSH_DRIVE_HEALTH)
    [ -n "$url" ] || return 0
    curl -fsS -m 10 --get --data-urlencode "status=$1" --data-urlencode "msg=$2" "$url" >/dev/null 2>&1 || true
}

command -v smartctl >/dev/null || { log "ERROR: smartctl not found - brew install smartmontools"; heartbeat down "smartctl missing"; exit 1; }

TEMP_WARN=$(get_env DRIVE_TEMP_WARN); TEMP_WARN="${TEMP_WARN:-55}"

problems=()
checked=0
unsupported=0

for dev in $(diskutil list physical | awk '/^\/dev\/disk/ {print $1}'); do
    out=$(smartctl -i -H -A "$dev" 2>&1)
    if echo "$out" | grep -q "Operation not supported by device\|Unable to detect device type"; then
        unsupported=$((unsupported + 1))
        continue
    fi
    checked=$((checked + 1))

    model=$(echo "$out" | awk -F': +' '/Device Model|Model Number/ {print $2; exit}')
    label="${dev#/dev/} (${model:-unknown})"

    # SMART's own verdict: anything but PASSED means the drive predicts failure
    health=$(echo "$out" | awk -F': ' '/overall-health/ {print $NF}' | tr -d ' ')
    [ "$health" = "PASSED" ] || problems+=("$label health=$health")

    # Attribute 194 (temperature) and the sector counts that precede a failure
    temp=$(echo "$out" | awk '/Temperature_Celsius|Airflow_Temperature/ {print $10; exit}')
    realloc=$(echo "$out" | awk '/Reallocated_Sector_Ct/ {print $10; exit}')
    pending=$(echo "$out" | awk '/Current_Pending_Sector/ {print $10; exit}')

    [ -n "${temp:-}" ] && [ "$temp" -gt "$TEMP_WARN" ] 2>/dev/null && problems+=("$label ${temp}C above ${TEMP_WARN}C")
    [ -n "${realloc:-}" ] && [ "$realloc" -gt 0 ] 2>/dev/null && problems+=("$label $realloc reallocated sectors")
    [ -n "${pending:-}" ] && [ "$pending" -gt 0 ] 2>/dev/null && problems+=("$label $pending pending sectors")

    log "OK   $label health=${health:-?} temp=${temp:-?}C realloc=${realloc:-0} pending=${pending:-0}"
done

[ "$unsupported" -gt 0 ] && log "NOTE $unsupported drive(s) cannot report S.M.A.R.T. (USB enclosures)"

# AppleRAID membership works for every drive, including the USB enclosure that
# cannot report S.M.A.R.T.: a disk that dies or drops out stops being "Online".
raid=$(diskutil appleRAID list 2>/dev/null)
if [ -n "$raid" ]; then
    while IFS= read -r line; do
        set_name=$(echo "$line" | sed -E 's/^Name: +//')
        [ -n "$set_name" ] && log "RAID set $set_name"
    done < <(echo "$raid" | grep -E '^Name:')
    members=$(echo "$raid" | grep -cE '^[0-9]+ +disk')
    degraded=$(echo "$raid" | grep -E '^[0-9]+ +disk' | grep -vc 'Online')
    if [ "$degraded" -gt 0 ]; then
        problems+=("$degraded of $members RAID members not Online")
    else
        log "OK   all $members RAID members Online"
    fi
    bad_sets=$(echo "$raid" | grep -E '^Status:' | grep -vc 'Online')
    [ "$bad_sets" -gt 0 ] && problems+=("$bad_sets RAID set(s) not Online")
fi

if [ "$checked" -eq 0 ]; then
    log "ERROR: no drive reported S.M.A.R.T. data"
    heartbeat down "no drive reported SMART data"
    exit 1
fi

if [ ${#problems[@]} -eq 0 ]; then
    log "All $checked drive(s) healthy"
    heartbeat up "$checked drives healthy, $unsupported without SMART, ${members:-0} RAID members online"
    exit 0
fi

for p in "${problems[@]}"; do log "WARN $p"; done
heartbeat down "$(IFS='; '; echo "${problems[*]}")"
exit 1
