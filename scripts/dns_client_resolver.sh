#!/usr/bin/env bash
# scripts/dns_client_resolver.sh - Client-side DNS failover resolver

DOMAIN="${1:-app.cnproject.test}"
RECORD_TYPE="${2:-A}"

PRIMARY_HOST="127.0.0.1"
PRIMARY_PORT="5355"
BACKUP_HOST="127.0.0.1"
BACKUP_PORT="5354"
TIMEOUT=1

echo "=================================================="
echo "Resolving: $DOMAIN ($RECORD_TYPE)"
echo "Configured Primary DNS: $PRIMARY_HOST:$PRIMARY_PORT"
echo "Configured Backup DNS : $BACKUP_HOST:$BACKUP_PORT"
echo "=================================================="

query_dns() {
    local host="$1"
    local port="$2"
    # Dig with short answer, ignoring comments and headers
    dig @"$host" -p "$port" "$DOMAIN" "$RECORD_TYPE" +short +time="$TIMEOUT" +tries=1 2>/dev/null | grep -E -v '^;|^$' || true
}

# 1. Try Primary DNS first
PRIMARY_RES=$(query_dns "$PRIMARY_HOST" "$PRIMARY_PORT")

if [[ -n "$PRIMARY_RES" ]]; then
    echo "[DNS Client] SUCCESS: Answered by Primary DNS ($PRIMARY_HOST:$PRIMARY_PORT)"
    echo "[DNS Client] Answer: $PRIMARY_RES"
    exit 0
fi

# 2. Primary DNS failed or timed out -> Failover to Backup DNS
echo "[DNS Client] WARNING: Primary DNS ($PRIMARY_HOST:$PRIMARY_PORT) unreachable or returned empty."
echo "[DNS Client] INITIATING FAILOVER -> Querying Backup DNS ($BACKUP_HOST:$BACKUP_PORT)..."

BACKUP_RES=$(query_dns "$BACKUP_HOST" "$BACKUP_PORT")

if [[ -n "$BACKUP_RES" ]]; then
    echo "[DNS Client] FAILOVER SUCCESS: Answered by Backup DNS ($BACKUP_HOST:$BACKUP_PORT)"
    echo "[DNS Client] Answer: $BACKUP_RES"
    exit 0
else
    echo "[DNS Client] FATAL ERROR: Both Primary and Backup DNS servers failed to resolve $DOMAIN."
    exit 1
fi
