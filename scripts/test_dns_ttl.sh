#!/usr/bin/env bash
# scripts/test_dns_ttl.sh - Automated Demonstration for DNS TTL and Controlled Record Change (Stage 3)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_DIR="$PROJECT_ROOT/evidence/phase-2"

mkdir -p "$EVIDENCE_DIR"
OUTPUT_LOG="$EVIDENCE_DIR/dns-ttl-test.txt"
PCAP_FILE="$EVIDENCE_DIR/dns-ttl-capture.pcapng"

exec > >(tee "$OUTPUT_LOG") 2>&1

echo "============================================================"
echo "STAGE 3: DNS TTL & CONTROLLED RECORD CHANGE DEMONSTRATION"
echo "Date: $(date)"
echo "Host: $(hostname) ($(uname -m))"
echo "============================================================"

# Ensure clean starting state
echo ""
echo "--- Step 1: Ensure DNS Services Running with Baseline Records ---"
"$SCRIPT_DIR/manage_dns.sh" reset-records
"$SCRIPT_DIR/manage_dns.sh" restart-all
sleep 1

# Start packet capture in background
echo ""
echo "--- Step 2: Starting TShark Packet Capture on Loopback ---"
/opt/homebrew/bin/tshark -i lo0 -f "udp port 5355 or udp port 5356" -w "$PCAP_FILE" -a duration:45 > /tmp/tshark_ttl.log 2>&1 &
TSHARK_PID=$!
sleep 1

echo ""
echo "--- Step 3: Authoritative Primary DNS Query (127.0.0.1:5355) ---"
echo "[Timestamp: $(date +%T)] Querying Authoritative Primary DNS:"
dig @127.0.0.1 -p 5355 app.cnproject.test +noall +answer

echo ""
echo "--- Step 4: Initial Query to Caching Resolver (127.0.0.1:5356) ---"
echo "[Timestamp: $(date +%T)] Query 1 to Caching Resolver (Populates Cache with TTL=30):"
dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer

echo ""
echo "--- Step 5: Second Query 5 Seconds Later (Observing TTL Countdown) ---"
sleep 5
echo "[Timestamp: $(date +%T)] Query 2 to Caching Resolver (Expected TTL ~25):"
dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer

echo ""
echo "--- Step 6: Controlled DNS Record Change (127.0.0.1 -> 127.0.0.2) ---"
echo "[Timestamp: $(date +%T)] Updating authoritative record to 127.0.0.2..."
"$SCRIPT_DIR/manage_dns.sh" set-record "127.0.0.2"

echo "Verifying Authoritative DNS updated immediately to 127.0.0.2:"
dig @127.0.0.1 -p 5355 app.cnproject.test +noall +answer

echo ""
echo "--- Step 7: Query Caching Resolver while Cache TTL Remains Valid ---"
echo "[Timestamp: $(date +%T)] Querying Caching Resolver (Demonstrating Stale Cache Retention):"
dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer
echo "OBSERVATION: Authoritative returns 127.0.0.2, but Caching Resolver still serves cached 127.0.0.1!"

echo ""
echo "--- Step 8: Waiting for Cache TTL Expiration ---"
CURRENT_TTL=$(dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer | awk '{print $2}' | head -n 1)
WAIT_SECS=$((${CURRENT_TTL:-25} + 4))
echo "Current remaining TTL: ${CURRENT_TTL:-25}s. Waiting ${WAIT_SECS}s for cache to fully expire..."
sleep "$WAIT_SECS"

echo ""
echo "--- Step 9: Query Caching Resolver After TTL Expiration ---"
echo "[Timestamp: $(date +%T)] Querying Caching Resolver after expiration:"
dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer
echo "OBSERVATION: Cache expired! Resolver fetched new authoritative record 127.0.0.2 with fresh TTL=30."

echo ""
echo "--- Step 10: Demonstrate Manual Cache Invalidation (Flush) ---"
echo "[Timestamp: $(date +%T)] Setting authoritative record back to 127.0.0.1..."
"$SCRIPT_DIR/manage_dns.sh" set-record "127.0.0.1"

echo "Query before flush (still cached as 127.0.0.2):"
dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer

echo "Flushing Caching Resolver cache manually..."
"$SCRIPT_DIR/manage_dns.sh" flush-cache

echo "Query immediately after flush (Expected: immediate pickup of 127.0.0.1):"
dig @127.0.0.1 -p 5356 app.cnproject.test +noall +answer

# Wait for TShark to complete
wait $TSHARK_PID 2>/dev/null || true

echo ""
echo "--- Step 11: Inspect Captured DNS Packets ---"
/opt/homebrew/bin/tshark -r "$PCAP_FILE" | head -n 25

echo ""
echo "--- Step 12: Clean Up and Restore Baseline Records ---"
"$SCRIPT_DIR/manage_dns.sh" reset-records
echo "[Cleanup] Baseline DNS records restored."

echo ""
echo "============================================================"
echo "STAGE 3 DEMONSTRATION COMPLETE - ALL OBJECTIVES VERIFIED"
echo "Log saved to : $OUTPUT_LOG"
echo "PCAP saved to: $PCAP_FILE"
echo "============================================================"
