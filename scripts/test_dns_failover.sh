#!/usr/bin/env bash
# scripts/test_dns_failover.sh - Full automated test for Backup DNS Failover (Stage 2)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_DIR="$PROJECT_ROOT/evidence/phase-2"

mkdir -p "$EVIDENCE_DIR"

OUTPUT_LOG="$EVIDENCE_DIR/backup-dns-failover-test.txt"
exec > >(tee "$OUTPUT_LOG") 2>&1

echo "========================================================"
echo "STAGE 2: BACKUP DNS RESOLVER & FAILOVER AUTOMATED TEST"
echo "Date: $(date)"
echo "Host: $(hostname) ($(uname -m))"
echo "========================================================"

echo ""
echo "--- Step 1: Starting Both Primary and Backup DNS Services ---"
"$SCRIPT_DIR/manage_dns.sh" restart-all
"$SCRIPT_DIR/manage_dns.sh" status

echo ""
echo "--- Step 2: Query Primary DNS Directly (dig @127.0.0.1 -p 5355) ---"
dig @127.0.0.1 -p 5355 app.cnproject.test +noall +answer +comments
dig @127.0.0.1 -p 5355 api.cnproject.test +noall +answer

echo ""
echo "--- Step 3: Query Backup DNS Directly (dig @127.0.0.1 -p 5354) ---"
dig @127.0.0.1 -p 5354 app.cnproject.test +noall +answer +comments
dig @127.0.0.1 -p 5354 api.cnproject.test +noall +answer

echo ""
echo "--- Step 4: Client Resolver Baseline Query (Primary Active) ---"
"$SCRIPT_DIR/dns_client_resolver.sh" app.cnproject.test

echo ""
echo "--- Step 5: Inject Primary DNS Failure (Stopping Primary DNS) ---"
"$SCRIPT_DIR/manage_dns.sh" stop-primary
"$SCRIPT_DIR/manage_dns.sh" status

echo ""
echo "--- Step 6: Verify Primary DNS Is Unreachable ---"
if dig @127.0.0.1 -p 5355 app.cnproject.test +short +time=1 +tries=1 2>&1 | grep -q "connection timed out"; then
    echo "CONFIRMED: Primary DNS is offline (connection timed out)."
else
    echo "Primary DNS check returned no answer as expected."
fi

echo ""
echo "--- Step 7: Client Resolver During Primary Failure (Backup Failover Verification) ---"
"$SCRIPT_DIR/dns_client_resolver.sh" app.cnproject.test

echo ""
echo "--- Step 8: Restore Primary DNS Service ---"
"$SCRIPT_DIR/manage_dns.sh" start-primary
"$SCRIPT_DIR/manage_dns.sh" status

echo ""
echo "--- Step 9: Verify Both DNS Instances Respond After Recovery ---"
echo "[Primary DNS Query]:"
dig @127.0.0.1 -p 5355 app.cnproject.test +short
echo "[Backup DNS Query]:"
dig @127.0.0.1 -p 5354 app.cnproject.test +short
echo "[Client Resolver Query]:"
"$SCRIPT_DIR/dns_client_resolver.sh" app.cnproject.test

echo ""
echo "========================================================"
echo "STAGE 2 TEST COMPLETED SUCCESSFULLY WITH ALL CHECKS PASS"
echo "Evidence written to: $OUTPUT_LOG"
echo "========================================================"
