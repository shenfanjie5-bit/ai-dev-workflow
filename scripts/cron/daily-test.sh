#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/daily-test-${TIMESTAMP}.log"

echo "=== Daily Test Run: ${TIMESTAMP} ===" | tee "$LOG_FILE"

cd "$REPO_DIR"

# ── Detect test runner and execute ──────────────────────
EXIT_CODE=0

if [[ -f "pnpm-lock.yaml" ]]; then
  echo "Running: pnpm test" | tee -a "$LOG_FILE"
  pnpm test 2>&1 | tee -a "$LOG_FILE" || EXIT_CODE=$?
elif [[ -f "package-lock.json" ]]; then
  echo "Running: npm test" | tee -a "$LOG_FILE"
  npm test 2>&1 | tee -a "$LOG_FILE" || EXIT_CODE=$?
elif [[ -f "pyproject.toml" || -f "setup.py" ]]; then
  echo "Running: pytest" | tee -a "$LOG_FILE"
  pytest --tb=short 2>&1 | tee -a "$LOG_FILE" || EXIT_CODE=$?
elif [[ -f "go.mod" ]]; then
  echo "Running: go test" | tee -a "$LOG_FILE"
  go test ./... -v 2>&1 | tee -a "$LOG_FILE" || EXIT_CODE=$?
else
  echo "[WARN] No recognized test configuration found." | tee -a "$LOG_FILE"
fi

# ── Summary ─────────────────────────────────────────────
echo "" | tee -a "$LOG_FILE"
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "=== Tests PASSED ===" | tee -a "$LOG_FILE"
else
  echo "=== Tests FAILED (exit code: ${EXIT_CODE}) ===" | tee -a "$LOG_FILE"
fi

exit $EXIT_CODE
