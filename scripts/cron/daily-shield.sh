#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Daily AgentShield Security Scan: ${TIMESTAMP} ==="

cd "$REPO_DIR"

# Run AgentShield scan on the workflow configuration
SCAN_OUTPUT=$(npx ecc-agentshield@1.3.0 scan 2>&1) || true
echo "$SCAN_OUTPUT" | tee "${LOG_DIR}/daily-shield-${TIMESTAMP}.log"

# Extract findings summary
CRITICAL=$(echo "$SCAN_OUTPUT" | grep -o '[0-9]* critical' | head -1 | grep -o '[0-9]*' || echo "0")
HIGH=$(echo "$SCAN_OUTPUT" | grep -o '[0-9]* high' | head -1 | grep -o '[0-9]*' || echo "0")

echo ""
echo "Summary: ${CRITICAL:-0} critical, ${HIGH:-0} high findings"

if [[ "${CRITICAL:-0}" != "0" ]]; then
  echo "[ALERT] Critical security findings detected! Review logs immediately."
  exit 1
fi

echo "=== Done ==="
