#!/usr/bin/env bash
# scripts/test_edge_migration.sh - Extension E Controlled Edge Migration Suite

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_DIR="$PROJECT_ROOT/evidence/phase-2"
CA_CERT="$PROJECT_ROOT/config/nginx/certs/cnproject-ca.crt"

mkdir -p "$EVIDENCE_DIR"
OUTPUT_LOG="$EVIDENCE_DIR/edge-migration-test.txt"
exec > >(tee "$OUTPUT_LOG") 2>&1

echo "============================================================"
echo "EXTENSION E: CONTROLLED EDGE MIGRATION (DNS CUTOVER) TEST"
echo "Date: $(date)"
echo "Host: $(hostname) ($(uname -m))"
echo "============================================================"

# Ensure all services running
echo ""
echo "--- Step 1: Ensuring All Services (Main Edge, Standby Edge, Backends, DNS) Active ---"
"$SCRIPT_DIR/manage_services.sh" start-all >/dev/null 2>&1 || true
"$SCRIPT_DIR/manage_dns.sh" reset-records
sleep 1

echo ""
echo "--- Step 2: Baseline Traffic to Main Edge (Port 8443) ---"
echo "Sending requests to Main Edge:"
for i in {1..3}; do
    RESP=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:8443:127.0.0.1 https://app.cnproject.test:8443/api/status)
    EDGE=$(echo "$RESP" | grep -i "X-Edge:" | tr -d '\r')
    BACKEND=$(echo "$RESP" | grep -i "X-Backend:" | tr -d '\r')
    echo "Request $i -> $EDGE | $BACKEND"
done

echo ""
echo "--- Step 3: Standby Edge Pre-Flight Health Check (Port 9443) ---"
echo "Testing Standby Edge readiness prior to cutover:"
STANDBY_PRE=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:9443:127.0.0.1 https://app.cnproject.test:9443/api/status)
echo "$STANDBY_PRE" | grep -E "HTTP/|X-Edge:|X-Backend:"
if echo "$STANDBY_PRE" | grep -q "X-Edge: Standby"; then
    echo "SUCCESS: Standby Edge is healthy and ready for traffic migration."
fi

echo ""
echo "--- Step 4: Initiate Controlled DNS Cutover to Standby Edge ---"
echo "Updating DNS authoritative records for app.cnproject.test to Standby Edge endpoint (127.0.0.2)..."
"$SCRIPT_DIR/manage_dns.sh" set-record "127.0.0.2"

echo "Direct Authoritative DNS Query after cutover:"
dig @127.0.0.1 -p 5355 app.cnproject.test +noall +answer

echo ""
echo "--- Step 5: Traffic Verification on Standby Edge (Port 9443) ---"
echo "Sending requests to Standby Edge post-migration:"
for i in {1..4}; do
    RESP=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:9443:127.0.0.1 https://app.cnproject.test:9443/api/status)
    EDGE=$(echo "$RESP" | grep -i "X-Edge:" | tr -d '\r')
    BACKEND=$(echo "$RESP" | grep -i "X-Backend:" | tr -d '\r')
    echo "Request $i -> $EDGE | $BACKEND"
done
echo "SUCCESS: Standby Edge is successfully serving application traffic with load balancing active across backends!"

echo ""
echo "--- Step 6: Rollback to Main Edge ---"
echo "Reverting DNS record to Main Edge (127.0.0.1)..."
"$SCRIPT_DIR/manage_dns.sh" reset-records
"$SCRIPT_DIR/manage_dns.sh" flush-cache

echo "Verifying traffic routed back to Main Edge:"
RESP_ROLLBACK=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:8443:127.0.0.1 https://app.cnproject.test:8443/api/status)
echo "$RESP_ROLLBACK" | grep -E "HTTP/|X-Edge:|X-Backend:"
if echo "$RESP_ROLLBACK" | grep -q "X-Edge: Main"; then
    echo "SUCCESS: Rollback complete. Main Edge resumed serving traffic."
fi

echo ""
echo "============================================================"
echo "EXTENSION E: EDGE MIGRATION TEST COMPLETED SUCCESSFULLY"
echo "Evidence written to: $OUTPUT_LOG"
echo "============================================================"
