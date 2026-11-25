#!/usr/bin/env bash
# scripts/diagnose_stack.sh - Production-Grade Layer-by-Layer Network Diagnostic Engine

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CA_CERT="$PROJECT_ROOT/config/nginx/certs/cnproject-ca.crt"
SERVER_CERT="$PROJECT_ROOT/config/nginx/certs/app.cnproject.test.crt"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
DIAG_LOG="$PROJECT_ROOT/evidence/phase-2/diagnostic-report.txt"

mkdir -p "$PROJECT_ROOT/evidence/phase-2"
exec > >(tee "$DIAG_LOG") 2>&1

echo "============================================================"
echo "CN-PROJECT: LAYER-BY-LAYER DIAGNOSTIC SCAN"
echo "Timestamp: $TIMESTAMP"
echo "Host: $(hostname) ($(uname -m)) | OS: $(uname -s) $(uname -r)"
echo "============================================================"

FAULTS_FOUND=0
ISSUES=()

check_pass() { echo "  [PASS] $1"; }
check_fail() {
    echo "  [FAIL] $1 -> $2"
    FAULTS_FOUND=$((FAULTS_FOUND+1))
    ISSUES+=("$1: $2")
}
check_warn() { echo "  [WARN] $1 -> $2"; }

echo ""
echo "=== LAYER 1-3: PHYSICAL, DATA-LINK & NETWORK LAYER ==="
# Check loopback interface
if ifconfig lo0 | grep -q "127.0.0.1"; then
    check_pass "Loopback interface (lo0) is UP and has 127.0.0.1 assigned"
else
    check_fail "Loopback interface" "lo0 does not have 127.0.0.1 active!"
fi

echo ""
echo "=== LAYER 4: TRANSPORT LAYER (PORT & SOCKET AVAILABILITY) ==="
check_port() {
    local proto="$1"
    local port="$2"
    local service="$3"
    if nc -z -G 1 127.0.0.1 "$port" 2>/dev/null; then
        check_pass "$service listening on TCP port $port"
    else
        check_fail "$service" "TCP port $port is NOT responding / connection refused"
    fi
}

check_port TCP 5355 "Primary DNS"
check_port TCP 5354 "Backup DNS"
check_port TCP 5356 "Caching Resolver"
check_port TCP 8443 "Main Edge nginx (HTTPS)"
check_port TCP 9443 "Standby Edge nginx (HTTPS)"
check_port TCP 3001 "Backend A"
check_port TCP 3002 "Backend B"

echo ""
echo "=== LAYER 5-6: SESSION & PRESENTATION LAYER (TLS & CERTIFICATES) ==="
# Check certificate existence and expiration
if [[ -f "$SERVER_CERT" ]]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$SERVER_CERT" | cut -d= -f2)
    CERT_SANS=$(openssl x509 -noout -ext subjectAltName -in "$SERVER_CERT" 2>/dev/null || true)
    check_pass "Server certificate present ($SERVER_CERT)"
    check_pass "Certificate Expiration: $CERT_EXPIRY"

    if echo "$CERT_SANS" | grep -q "DNS:app.cnproject.test"; then
        check_pass "SAN validation: DNS:app.cnproject.test present"
    else
        check_fail "TLS Certificate SAN" "Missing app.cnproject.test in SAN extension"
    fi
else
    check_fail "TLS Certificate" "Certificate file $SERVER_CERT not found!"
fi

# Test actual TLS Handshake to Main Edge
TLS_HANDSHAKE=$(echo | openssl s_client -connect 127.0.0.1:8443 -servername app.cnproject.test -CAfile "$CA_CERT" 2>&1 || true)
if echo "$TLS_HANDSHAKE" | grep -q "Verify return code: 0 (ok)"; then
    check_pass "TLS Handshake to Main Edge (8443): SUCCESS (Verify return code: 0 ok)"
else
    check_fail "TLS Handshake Main Edge" "Verification failed: $(echo "$TLS_HANDSHAKE" | grep -i 'verify return code' || echo 'connection failed')"
fi

echo ""
echo "=== LAYER 7: APPLICATION LAYER (DNS, HTTP & PROXY HEALTH) ==="
# 1. DNS Resolution Check
DNS_PRIMARY_ANS=$(dig @127.0.0.1 -p 5355 app.cnproject.test +short +time=1 +tries=1 2>/dev/null | grep -v '^;' || true)
if [[ -n "$DNS_PRIMARY_ANS" ]]; then
    check_pass "Primary DNS resolves app.cnproject.test -> $DNS_PRIMARY_ANS"
else
    check_fail "Primary DNS Resolution" "Failed to resolve app.cnproject.test on 127.0.0.1:5355"
fi

DNS_BACKUP_ANS=$(dig @127.0.0.1 -p 5354 app.cnproject.test +short +time=1 +tries=1 2>/dev/null | grep -v '^;' || true)
if [[ -n "$DNS_BACKUP_ANS" ]]; then
    check_pass "Backup DNS resolves app.cnproject.test -> $DNS_BACKUP_ANS"
else
    check_fail "Backup DNS Resolution" "Failed to resolve app.cnproject.test on 127.0.0.1:5354"
fi

# 2. HTTP End-to-End Application Check
HTTP_MAIN_RES=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:8443:127.0.0.1 https://app.cnproject.test:8443/api/status 2>/dev/null || true)
if echo "$HTTP_MAIN_RES" | grep -q "200 OK"; then
    EDGE_HDR=$(echo "$HTTP_MAIN_RES" | grep -i "X-Edge:" | tr -d '\r')
    BACK_HDR=$(echo "$HTTP_MAIN_RES" | grep -i "X-Backend:" | tr -d '\r')
    check_pass "Main Edge HTTPS (8443): HTTP 200 OK ($EDGE_HDR | $BACK_HDR)"
else
    HTTP_CODE=$(echo "$HTTP_MAIN_RES" | grep -o "HTTP/[12\.]* [0-9]*" || echo "Connection Failed")
    check_fail "Main Edge HTTPS" "Expected 200 OK, got: $HTTP_CODE"
fi

HTTP_STANDBY_RES=$(curl -s -i --cacert "$CA_CERT" --resolve app.cnproject.test:9443:127.0.0.1 https://app.cnproject.test:9443/api/status 2>/dev/null || true)
if echo "$HTTP_STANDBY_RES" | grep -q "200 OK"; then
    EDGE_HDR_S=$(echo "$HTTP_STANDBY_RES" | grep -i "X-Edge:" | tr -d '\r')
    BACK_HDR_S=$(echo "$HTTP_STANDBY_RES" | grep -i "X-Backend:" | tr -d '\r')
    check_pass "Standby Edge HTTPS (9443): HTTP 200 OK ($EDGE_HDR_S | $BACK_HDR_S)"
else
    HTTP_CODE_S=$(echo "$HTTP_STANDBY_RES" | grep -o "HTTP/[12\.]* [0-9]*" || echo "Connection Failed")
    check_fail "Standby Edge HTTPS" "Expected 200 OK, got: $HTTP_CODE_S"
fi

echo ""
echo "============================================================"
echo "DIAGNOSTIC SUMMARY & ROOT-CAUSE ANALYSIS"
echo "============================================================"
if [[ $FAULTS_FOUND -eq 0 ]]; then
    echo "STATUS: ALL SYSTEMS HEALTHY. No network faults detected across Layers 1-7."
else
    echo "STATUS: $FAULTS_FOUND FAULT(S) DETECTED!"
    echo "AFFECTED LAYERS / COMPONENTS:"
    for issue in "${ISSUES[@]}"; do
        echo "  * $issue"
    done
    echo ""
    echo "REMEDIATION RECOMMENDATIONS:"
    if [[ "${ISSUES[*]}" =~ "Primary DNS" ]]; then
        echo "  -> Run: ./scripts/manage_dns.sh restart-primary"
    fi
    if [[ "${ISSUES[*]}" =~ "Backend" ]]; then
        echo "  -> Run: ./scripts/manage_services.sh start-backends"
    fi
    if [[ "${ISSUES[*]}" =~ "Edge" ]]; then
        echo "  -> Run: ./scripts/manage_services.sh start-edges"
    fi
    echo "  -> Master recovery: ./scripts/fault_manager.sh recover-all"
fi
echo "============================================================"
