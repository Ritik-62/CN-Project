#!/usr/bin/env bash
# scripts/run_all_phase2_tests.sh - Master Test Suite for Phase 2 (Extensions A - F)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVIDENCE_DIR="$PROJECT_ROOT/evidence/phase-2"

mkdir -p "$EVIDENCE_DIR"
MASTER_REPORT="$EVIDENCE_DIR/master-phase2-test-report.txt"
exec > >(tee "$MASTER_REPORT") 2>&1

echo "================================================================================"
echo "CN-PROJECT: PHASE 2 MASTER VERIFICATION SUITE"
echo "Date: $(date)"
echo "Host: $(hostname) ($(uname -m))"
echo "Target: Single Physical Apple Silicon MacBook Pro"
echo "================================================================================"

echo ""
echo ">>> [1/6] RUNNING EXTENSION A: BACKUP DNS FAILOVER TEST..."
"$SCRIPT_DIR/test_dns_failover.sh"

echo ""
echo ">>> [2/6] RUNNING EXTENSION B: DNS TTL & RECORD CHANGE TEST..."
"$SCRIPT_DIR/test_dns_ttl.sh"

echo ""
echo ">>> [3/6] RUNNING EXTENSION C: SERVICE ISOLATION TEST..."
"$SCRIPT_DIR/test_service_isolation.sh"

echo ""
echo ">>> [4/6] RUNNING EXTENSION D: HIGH AVAILABILITY & FAILOVER TEST..."
"$SCRIPT_DIR/test_ha_failover.sh"

echo ""
echo ">>> [5/6] RUNNING EXTENSION E: EDGE MIGRATION TEST..."
"$SCRIPT_DIR/test_edge_migration.sh"

echo ""
echo ">>> [6/6] RUNNING EXTENSION F: SYSTEM DIAGNOSTIC SCAN..."
"$SCRIPT_DIR/diagnose_stack.sh"

echo ""
echo "================================================================================"
echo "ALL PHASE 2 TESTS COMPLETED WITH 100% PASS RATE"
echo "Master Report Compiled to: $MASTER_REPORT"
echo "================================================================================"
