#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Daily Test Run: ${TIMESTAMP} ==="

cd "$REPO_DIR"

# Run tests via Claude Code in non-interactive mode
claude -p "Run 'pnpm test' and summarize results. If any tests fail, list the failing test names and file paths." \
  --output-format text \
  2>&1 | tee "${LOG_DIR}/daily-test-${TIMESTAMP}.log"

echo "=== Done ==="
