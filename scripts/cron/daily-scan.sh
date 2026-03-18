#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Daily Code Scan: ${TIMESTAMP} ==="

cd "$REPO_DIR"

# Scan for TODOs, FIXMEs, and failing tests
claude -p "Search the codebase for TODO and FIXME comments. Group by file. Also check if any test files contain .skip or .only that might have been left in accidentally." \
  --output-format text \
  2>&1 | tee "${LOG_DIR}/daily-scan-${TIMESTAMP}.log"

echo "=== Done ==="
