#!/usr/bin/env bash
# scripts/fault_manager.sh - Controlled Fault Injection & Recovery Manager (Extension F)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

inject_fault() {
    local fault="$1"
    echo "============================================================"
    echo "[Fault Manager] INJECTING FAULT: $fault"
    echo "============================================================"
    case "$fault" in
        dns-primary-down)
            echo "Stopping Primary DNS process (127.0.0.1:5355)..."
            "$SCRIPT_DIR/manage_dns.sh" stop-primary
            echo "Fault Injected: Primary DNS is offline."
            ;;
        dns-backup-down)
            echo "Stopping Backup DNS process (127.0.0.1:5354)..."
            "$SCRIPT_DIR/manage_dns.sh" stop-backup
            echo "Fault Injected: Backup DNS is offline."
            ;;
        dns-wrong-record)
            echo "Modifying authoritative record to non-existent IP 192.0.2.123..."
            "$SCRIPT_DIR/manage_dns.sh" set-record "192.0.2.123"
            echo "Fault Injected: DNS returns wrong IP."
            ;;
        backend-a-down)
            echo "Stopping Backend A (Port 3001)..."
            if [[ -f /tmp/backend-a.pid ]]; then
                kill "$(cat /tmp/backend-a.pid)" 2>/dev/null || true
                rm -f /tmp/backend-a.pid
            fi
            echo "Fault Injected: Backend A is down."
            ;;
        backend-b-down)
            echo "Stopping Backend B (Port 3002)..."
            if [[ -f /tmp/backend-b.pid ]]; then
                kill "$(cat /tmp/backend-b.pid)" 2>/dev/null || true
                rm -f /tmp/backend-b.pid
            fi
            echo "Fault Injected: Backend B is down."
            ;;
        both-backends-down)
            echo "Stopping both Backend A and Backend B..."
            "$SCRIPT_DIR/manage_services.sh" stop-backends
            echo "Fault Injected: All upstream backends are down (triggers 502 Bad Gateway)."
            ;;
        edge-main-down)
            echo "Stopping Main Edge nginx..."
            if [[ -f /tmp/nginx-main.pid ]]; then
                kill "$(cat /tmp/nginx-main.pid)" 2>/dev/null || true
                rm -f /tmp/nginx-main.pid
            fi
            echo "Fault Injected: Main Edge is offline."
            ;;
        *)
            echo "Unknown fault: $fault"
            echo "Available faults: dns-primary-down, dns-backup-down, dns-wrong-record, backend-a-down, backend-b-down, both-backends-down, edge-main-down"
            exit 1
            ;;
    esac
}

recover_fault() {
    local fault="$1"
    echo "============================================================"
    echo "[Fault Manager] RECOVERING FROM: $fault"
    echo "============================================================"
    case "$fault" in
        dns-primary)
            "$SCRIPT_DIR/manage_dns.sh" start-primary
            ;;
        dns-backup)
            "$SCRIPT_DIR/manage_dns.sh" start-backup
            ;;
        dns-record)
            "$SCRIPT_DIR/manage_dns.sh" reset-records
            "$SCRIPT_DIR/manage_dns.sh" flush-cache
            ;;
        backend-a|backend-b|backends)
            "$SCRIPT_DIR/manage_services.sh" start-backends
            ;;
        edge-main)
            "$SCRIPT_DIR/manage_services.sh" start-edges
            ;;
        recover-all)
            echo "[Fault Manager] Executing master recovery for all subsystems..."
            "$SCRIPT_DIR/manage_dns.sh" reset-records
            "$SCRIPT_DIR/manage_dns.sh" restart-all
            "$SCRIPT_DIR/manage_services.sh" start-backends
            "$SCRIPT_DIR/manage_services.sh" start-edges
            echo "[Fault Manager] Master recovery completed successfully."
            ;;
        *)
            echo "Unknown recovery target: $fault"
            exit 1
            ;;
    esac
}

case "$1" in
    inject) inject_fault "$2" ;;
    recover) recover_fault "$2" ;;
    recover-all) recover_fault "recover-all" ;;
    *)
        echo "Usage: $0 {inject <fault_name>|recover <target>|recover-all}"
        exit 1
        ;;
esac
