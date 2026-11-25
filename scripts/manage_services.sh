#!/usr/bin/env bash
# scripts/manage_services.sh - Master Orchestrator for Phase 2 Services (Single Mac)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PID_DIR="/tmp"
BACKEND_A_PID="$PID_DIR/backend-a.pid"
BACKEND_B_PID="$PID_DIR/backend-b.pid"
MAIN_EDGE_PID="$PID_DIR/nginx-main.pid"
STANDBY_EDGE_PID="$PID_DIR/nginx-standby.pid"

MAIN_EDGE_CONF="$PROJECT_ROOT/config/nginx/nginx-main.conf"
STANDBY_EDGE_CONF="$PROJECT_ROOT/config/nginx/nginx-standby.conf"

NGINX_BIN="/opt/homebrew/bin/nginx"

# Ensure cache directories exist
mkdir -p /tmp/nginx-cache-main /tmp/nginx-cache-standby

start_backends() {
    local isolation_flag="${ENABLE_ISOLATION:-0}"
    echo "[Backends] Starting Backend A (:3001) with ENABLE_ISOLATION=$isolation_flag..."
    if [[ -f "$BACKEND_A_PID" ]] && kill -0 "$(cat "$BACKEND_A_PID")" 2>/dev/null; then
        echo "[Backend A] Already running (PID $(cat "$BACKEND_A_PID"))"
    else
        ENABLE_ISOLATION="$isolation_flag" python3 -u "$PROJECT_ROOT/backends/backend-a/server.py" > /tmp/backend-a.log 2>&1 &
        echo $! > "$BACKEND_A_PID"
        echo "[Backend A] Started (PID $(cat "$BACKEND_A_PID"))"
    fi

    echo "[Backends] Starting Backend B (:3002) with ENABLE_ISOLATION=$isolation_flag..."
    if [[ -f "$BACKEND_B_PID" ]] && kill -0 "$(cat "$BACKEND_B_PID")" 2>/dev/null; then
        echo "[Backend B] Already running (PID $(cat "$BACKEND_B_PID"))"
    else
        ENABLE_ISOLATION="$isolation_flag" python3 -u "$PROJECT_ROOT/backends/backend-b/server.py" > /tmp/backend-b.log 2>&1 &
        echo $! > "$BACKEND_B_PID"
        echo "[Backend B] Started (PID $(cat "$BACKEND_B_PID"))"
    fi
}

stop_backends() {
    echo "[Backends] Stopping Backend A and Backend B..."
    if [[ -f "$BACKEND_A_PID" ]]; then
        kill "$(cat "$BACKEND_A_PID")" 2>/dev/null || true
        rm -f "$BACKEND_A_PID"
        echo "[Backend A] Stopped."
    fi
    if [[ -f "$BACKEND_B_PID" ]]; then
        kill "$(cat "$BACKEND_B_PID")" 2>/dev/null || true
        rm -f "$BACKEND_B_PID"
        echo "[Backend B] Stopped."
    fi
}

start_edges() {
    echo "[Edge] Validating Main Edge config..."
    "$NGINX_BIN" -t -c "$MAIN_EDGE_CONF" >/dev/null 2>&1 || { echo "[Edge] Main config syntax error!" >&2; exit 1; }

    echo "[Edge] Starting Main Edge (:8443 SSL / :8080 HTTP)..."
    if [[ -f "$MAIN_EDGE_PID" ]] && kill -0 "$(cat "$MAIN_EDGE_PID")" 2>/dev/null; then
        echo "[Main Edge] Already running (PID $(cat "$MAIN_EDGE_PID"))"
    else
        "$NGINX_BIN" -c "$MAIN_EDGE_CONF"
        echo "[Main Edge] Started."
    fi

    echo "[Edge] Validating Standby Edge config..."
    "$NGINX_BIN" -t -c "$STANDBY_EDGE_CONF" >/dev/null 2>&1 || { echo "[Edge] Standby config syntax error!" >&2; exit 1; }

    echo "[Edge] Starting Standby Edge (:9443 SSL / :9080 HTTP)..."
    if [[ -f "$STANDBY_EDGE_PID" ]] && kill -0 "$(cat "$STANDBY_EDGE_PID")" 2>/dev/null; then
        echo "[Standby Edge] Already running (PID $(cat "$STANDBY_EDGE_PID"))"
    else
        "$NGINX_BIN" -c "$STANDBY_EDGE_CONF"
        echo "[Standby Edge] Started."
    fi
}

stop_edges() {
    echo "[Edge] Stopping Main Edge and Standby Edge..."
    if [[ -f "$MAIN_EDGE_PID" ]]; then
        "$NGINX_BIN" -s stop -c "$MAIN_EDGE_CONF" 2>/dev/null || kill -9 "$(cat "$MAIN_EDGE_PID")" 2>/dev/null || true
        rm -f "$MAIN_EDGE_PID"
        echo "[Main Edge] Stopped."
    fi
    if [[ -f "$STANDBY_EDGE_PID" ]]; then
        "$NGINX_BIN" -s stop -c "$STANDBY_EDGE_CONF" 2>/dev/null || kill -9 "$(cat "$STANDBY_EDGE_PID")" 2>/dev/null || true
        rm -f "$STANDBY_EDGE_PID"
        echo "[Standby Edge] Stopped."
    fi
}

start_all() {
    echo "=== STARTING ALL LOGICAL SERVICES (PHASE 2 SINGLE MAC) ==="
    "$SCRIPT_DIR/manage_dns.sh" start-all
    start_backends
    start_edges
    sleep 1
    status
}

stop_all() {
    echo "=== STOPPING ALL SERVICES ==="
    stop_edges || true
    stop_backends || true
    "$SCRIPT_DIR/manage_dns.sh" stop-all || true
    echo "All services stopped."
}

status() {
    echo "============================================================"
    echo "PHASE 2 LOGICAL ARCHITECTURE SERVICE STATUS"
    echo "============================================================"
    echo "-- Machine 1: DNS Subsystem --"
    "$SCRIPT_DIR/manage_dns.sh" status

    echo ""
    echo "-- Machine 2: Edge Reverse Proxy (Main) --"
    if [[ -f "$MAIN_EDGE_PID" ]] && kill -0 "$(cat "$MAIN_EDGE_PID")" 2>/dev/null; then
        echo "Main Edge nginx    (127.0.0.1:8443 SSL / :8080 HTTP): RUNNING (PID $(cat "$MAIN_EDGE_PID"))"
    else
        echo "Main Edge nginx    (127.0.0.1:8443 SSL / :8080 HTTP): STOPPED"
    fi

    echo ""
    echo "-- Machine 3: Backend Server A --"
    if [[ -f "$BACKEND_A_PID" ]] && kill -0 "$(cat "$BACKEND_A_PID")" 2>/dev/null; then
        echo "Backend A          (127.0.0.1:3001): RUNNING (PID $(cat "$BACKEND_A_PID"))"
    else
        echo "Backend A          (127.0.0.1:3001): STOPPED"
    fi

    echo ""
    echo "-- Machine 4: Backend Server B & Standby Edge --"
    if [[ -f "$BACKEND_B_PID" ]] && kill -0 "$(cat "$BACKEND_B_PID")" 2>/dev/null; then
        echo "Backend B          (127.0.0.1:3002): RUNNING (PID $(cat "$BACKEND_B_PID"))"
    else
        echo "Backend B          (127.0.0.1:3002): STOPPED"
    fi
    if [[ -f "$STANDBY_EDGE_PID" ]] && kill -0 "$(cat "$STANDBY_EDGE_PID")" 2>/dev/null; then
        echo "Standby Edge nginx (127.0.0.1:9443 SSL / :9080 HTTP): RUNNING (PID $(cat "$STANDBY_EDGE_PID"))"
    else
        echo "Standby Edge nginx (127.0.0.1:9443 SSL / :9080 HTTP): STOPPED"
    fi
    echo "============================================================"
}

case "$1" in
    start-backends) start_backends ;;
    stop-backends) stop_backends ;;
    start-edges) start_edges ;;
    stop-edges) stop_edges ;;
    start-all) start_all ;;
    stop-all) stop_all ;;
    restart-all) stop_all; sleep 1; start_all ;;
    status) status ;;
    *)
        echo "Usage: $0 {start-all|stop-all|restart-all|start-backends|stop-backends|start-edges|stop-edges|status}"
        exit 1
        ;;
esac
