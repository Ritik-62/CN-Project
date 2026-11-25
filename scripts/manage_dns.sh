#!/usr/bin/env bash
# scripts/manage_dns.sh - Manage Primary, Backup, and Caching DNS for CN-Project Phase 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PRIMARY_CONF="$PROJECT_ROOT/config/dnsmasq/dnsmasq-primary.conf"
BACKUP_CONF="$PROJECT_ROOT/config/dnsmasq/dnsmasq-backup.conf"
CACHE_CONF="$PROJECT_ROOT/config/dnsmasq/dnsmasq-cache.conf"
HOSTS_FILE="$PROJECT_ROOT/config/dnsmasq/records.hosts"

PRIMARY_PID="/tmp/dnsmasq-primary.pid"
BACKUP_PID="/tmp/dnsmasq-backup.pid"
CACHE_PID="/tmp/dnsmasq-cache.pid"

DNSMASQ_BIN="/opt/homebrew/sbin/dnsmasq"
if [[ ! -x "$DNSMASQ_BIN" ]]; then
    DNSMASQ_BIN="$(which dnsmasq 2>/dev/null)"
fi

start_primary() {
    if [[ -f "$PRIMARY_PID" ]] && kill -0 "$(cat "$PRIMARY_PID")" 2>/dev/null; then
        echo "[Primary DNS] Already running (PID $(cat "$PRIMARY_PID"))"
        return 0
    fi
    echo "[Primary DNS] Starting on 127.0.0.1:5355 (TTL=30)..."
    "$DNSMASQ_BIN" -C "$PRIMARY_CONF"
    sleep 0.5
    if [[ -f "$PRIMARY_PID" ]] && kill -0 "$(cat "$PRIMARY_PID")" 2>/dev/null; then
        echo "[Primary DNS] Started successfully (PID $(cat "$PRIMARY_PID"))"
    else
        echo "[Primary DNS] Failed to start!" >&2
        return 1
    fi
}

stop_primary() {
    if [[ -f "$PRIMARY_PID" ]]; then
        PID="$(cat "$PRIMARY_PID")"
        if kill -0 "$PID" 2>/dev/null; then
            echo "[Primary DNS] Stopping (PID $PID)..."
            kill "$PID" 2>/dev/null || true
            sleep 0.5
        fi
        rm -f "$PRIMARY_PID"
        echo "[Primary DNS] Stopped."
    else
        echo "[Primary DNS] Not running."
    fi
}

start_backup() {
    if [[ -f "$BACKUP_PID" ]] && kill -0 "$(cat "$BACKUP_PID")" 2>/dev/null; then
        echo "[Backup DNS] Already running (PID $(cat "$BACKUP_PID"))"
        return 0
    fi
    echo "[Backup DNS] Starting on 127.0.0.1:5354 (TTL=30)..."
    "$DNSMASQ_BIN" -C "$BACKUP_CONF"
    sleep 0.5
    if [[ -f "$BACKUP_PID" ]] && kill -0 "$(cat "$BACKUP_PID")" 2>/dev/null; then
        echo "[Backup DNS] Started successfully (PID $(cat "$BACKUP_PID"))"
    else
        echo "[Backup DNS] Failed to start!" >&2
        return 1
    fi
}

stop_backup() {
    if [[ -f "$BACKUP_PID" ]]; then
        PID="$(cat "$BACKUP_PID")"
        if kill -0 "$PID" 2>/dev/null; then
            echo "[Backup DNS] Stopping (PID $PID)..."
            kill "$PID" 2>/dev/null || true
            sleep 0.5
        fi
        rm -f "$BACKUP_PID"
        echo "[Backup DNS] Stopped."
    else
        echo "[Backup DNS] Not running."
    fi
}

start_cache() {
    if [[ -f "$CACHE_PID" ]] && kill -0 "$(cat "$CACHE_PID")" 2>/dev/null; then
        echo "[Caching Resolver] Already running (PID $(cat "$CACHE_PID"))"
        return 0
    fi
    echo "[Caching Resolver] Starting on 127.0.0.1:5356..."
    "$DNSMASQ_BIN" -C "$CACHE_CONF"
    sleep 0.5
    if [[ -f "$CACHE_PID" ]] && kill -0 "$(cat "$CACHE_PID")" 2>/dev/null; then
        echo "[Caching Resolver] Started successfully (PID $(cat "$CACHE_PID"))"
    else
        echo "[Caching Resolver] Failed to start!" >&2
        return 1
    fi
}

stop_cache() {
    if [[ -f "$CACHE_PID" ]]; then
        PID="$(cat "$CACHE_PID")"
        if kill -0 "$PID" 2>/dev/null; then
            echo "[Caching Resolver] Stopping (PID $PID)..."
            kill "$PID" 2>/dev/null || true
            sleep 0.5
        fi
        rm -f "$CACHE_PID"
        echo "[Caching Resolver] Stopped."
    else
        echo "[Caching Resolver] Not running."
    fi
}

flush_cache() {
    if [[ -f "$CACHE_PID" ]] && kill -0 "$(cat "$CACHE_PID")" 2>/dev/null; then
        PID="$(cat "$CACHE_PID")"
        echo "[Caching Resolver] Flushing DNS cache (SIGHUP -> PID $PID)..."
        kill -HUP "$PID"
        sleep 0.5
        echo "[Caching Resolver] Cache flushed successfully."
    else
        echo "[Caching Resolver] Not running." >&2
        return 1
    fi
}

set_record() {
    local target_ip="$1"
    if [[ -z "$target_ip" ]]; then
        echo "Usage: $0 set-record <target_ip>" >&2
        return 1
    fi
    echo "[DNS Admin] Setting app.cnproject.test -> $target_ip in $HOSTS_FILE..."
    cat <<EOF > "$HOSTS_FILE"
$target_ip app.cnproject.test
$target_ip api.cnproject.test
EOF
    # Send SIGHUP to Primary and Backup DNS to reload records instantly
    if [[ -f "$PRIMARY_PID" ]] && kill -0 "$(cat "$PRIMARY_PID")" 2>/dev/null; then
        kill -HUP "$(cat "$PRIMARY_PID")"
        echo "[Primary DNS] Dynamic reload triggered."
    fi
    if [[ -f "$BACKUP_PID" ]] && kill -0 "$(cat "$BACKUP_PID")" 2>/dev/null; then
        kill -HUP "$(cat "$BACKUP_PID")"
        echo "[Backup DNS] Dynamic reload triggered."
    fi
    sleep 0.5
    echo "[DNS Admin] DNS record update complete."
}

reset_records() {
    set_record "127.0.0.1"
}

status_dns() {
    echo "=== DNS SERVICES STATUS ==="
    if [[ -f "$PRIMARY_PID" ]] && kill -0 "$(cat "$PRIMARY_PID")" 2>/dev/null; then
        echo "Primary DNS      (127.0.0.1:5355): RUNNING (PID $(cat "$PRIMARY_PID"))"
    else
        echo "Primary DNS      (127.0.0.1:5355): STOPPED"
    fi

    if [[ -f "$BACKUP_PID" ]] && kill -0 "$(cat "$BACKUP_PID")" 2>/dev/null; then
        echo "Backup DNS       (127.0.0.1:5354): RUNNING (PID $(cat "$BACKUP_PID"))"
    else
        echo "Backup DNS       (127.0.0.1:5354): STOPPED"
    fi

    if [[ -f "$CACHE_PID" ]] && kill -0 "$(cat "$CACHE_PID")" 2>/dev/null; then
        echo "Caching Resolver (127.0.0.1:5356): RUNNING (PID $(cat "$CACHE_PID"))"
    else
        echo "Caching Resolver (127.0.0.1:5356): STOPPED"
    fi
    echo "Current records in $HOSTS_FILE:"
    cat "$HOSTS_FILE" | sed 's/^/  /'
}

case "$1" in
    start-primary) start_primary ;;
    stop-primary) stop_primary ;;
    restart-primary) stop_primary; start_primary ;;
    start-backup) start_backup ;;
    stop-backup) stop_backup ;;
    restart-backup) stop_backup; start_backup ;;
    start-cache) start_cache ;;
    stop-cache) stop_cache ;;
    restart-cache) stop_cache; start_cache ;;
    flush-cache) flush_cache ;;
    set-record) set_record "$2" ;;
    reset-records) reset_records ;;
    start-all) start_primary; start_backup; start_cache ;;
    stop-all) stop_primary; stop_backup; stop_cache ;;
    restart-all) stop_primary; stop_backup; stop_cache; start_primary; start_backup; start_cache ;;
    status) status_dns ;;
    *)
        echo "Usage: $0 {start-primary|stop-primary|start-backup|stop-backup|start-cache|stop-cache|flush-cache|set-record <ip>|reset-records|start-all|stop-all|restart-all|status}"
        exit 1
        ;;
esac
