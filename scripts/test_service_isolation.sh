#!/usr/bin/env bash
# scripts/test_service_isolation.sh - Extension C Service Isolation Verification Suite

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_DIR="$PROJECT_ROOT/evidence/phase-2"
CA_CERT="$PROJECT_ROOT/config/nginx/certs/cnproject-ca.crt"

mkdir -p "$EVIDENCE_DIR"
OUTPUT_LOG="$EVIDENCE_DIR/service-isolation-test.txt"
exec > >(tee "$OUTPUT_LOG") 2>&1

echo "============================================================"
echo "EXTENSION C: SERVICE ISOLATION & BACKEND SECURITY TEST"
echo "Date: $(date)"
echo "Host: $(hostname) ($(uname -m))"
echo "============================================================"

# Ensure services running with ENABLE_ISOLATION=1
echo ""
echo "--- Step 1: Starting Backends with Service Isolation Enforced (ENABLE_ISOLATION=1) ---"
"$SCRIPT_DIR/manage_services.sh" stop-backends || true
ENABLE_ISOLATION=1 "$SCRIPT_DIR/manage_services.sh" start-backends
"$SCRIPT_DIR/manage_services.sh" start-edges
sleep 1

echo ""
echo "--- Step 2 [Scenario A]: Direct Client Access to Backend A (:3001) ---"
echo "Sending unauthenticated client request to http://127.0.0.1:3001/:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/ || true)
echo "Direct Access HTTP Status: $HTTP_CODE"
if [[ "$HTTP_CODE" == "403" ]]; then
    echo "SUCCESS: Direct client access to Backend A was BLOCKED (403 Forbidden) as required!"
    curl -i -s http://127.0.0.1:3001/ | grep -E "HTTP|X-Isolation-Status|error" || true
else
    echo "FAILURE: Expected 403 Forbidden, got $HTTP_CODE" >&2
    exit 1
fi

echo ""
echo "--- Step 3 [Scenario B]: Direct Client Access to Backend B (:3002) ---"
echo "Sending unauthenticated client request to http://127.0.0.1:3002/:"
HTTP_CODE_B=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3002/ || true)
echo "Direct Access HTTP Status: $HTTP_CODE_B"
if [[ "$HTTP_CODE_B" == "403" ]]; then
    echo "SUCCESS: Direct client access to Backend B was BLOCKED (403 Forbidden) as required!"
    curl -i -s http://127.0.0.1:3002/ | grep -E "HTTP|X-Isolation-Status|error" || true
else
    echo "FAILURE: Expected 403 Forbidden, got $HTTP_CODE_B" >&2
    exit 1
fi

echo ""
echo "--- Step 4 [Scenario C & E]: HTTPS Access Through Main Edge (Port 8443) ---"
echo "Sending HTTPS request via Main Edge reverse proxy:"
RESP_MAIN=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:8443:127.0.0.1 https://app.cnproject.test:8443/api/status)
echo "$RESP_MAIN" | grep -E "HTTP/|X-Backend:|X-Edge:|X-Isolation-Status:"
if echo "$RESP_MAIN" | grep -q "200 OK"; then
    echo "SUCCESS: Main Edge successfully authenticated with backend and returned HTTP 200 OK!"
else
    echo "FAILURE: Main Edge failed to authenticate with backend!" >&2
    exit 1
fi

echo ""
echo "--- Step 5 [Scenario D & E]: HTTPS Access Through Standby Edge (Port 9443) ---"
echo "Sending HTTPS request via Standby Edge reverse proxy:"
RESP_STANDBY=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:9443:127.0.0.1 https://app.cnproject.test:9443/api/status)
echo "$RESP_STANDBY" | grep -E "HTTP/|X-Backend:|X-Edge:|X-Isolation-Status:"
if echo "$RESP_STANDBY" | grep -q "200 OK"; then
    echo "SUCCESS: Standby Edge successfully authenticated with backend and returned HTTP 200 OK!"
else
    echo "FAILURE: Standby Edge failed to authenticate with backend!" >&2
    exit 1
fi

echo ""
echo "--- Step 6: Verify Isolation Rollback / Permissive Compatibility ---"
echo "Restarting Backends in default Permissive mode (ENABLE_ISOLATION=0)..."
"$SCRIPT_DIR/manage_services.sh" stop-backends
ENABLE_ISOLATION=0 "$SCRIPT_DIR/manage_services.sh" start-backends
sleep 1
PERM_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/ || true)
echo "Direct Access in Permissive Mode HTTP Status: $PERM_CODE"

echo ""
echo "============================================================"
echo "EXTENSION C: SERVICE ISOLATION TEST PASSED ALL 5 SCENARIOS"
echo "Evidence written to: $OUTPUT_LOG"
echo "============================================================"
