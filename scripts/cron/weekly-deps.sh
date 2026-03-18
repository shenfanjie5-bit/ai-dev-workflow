#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Weekly Dependency Check: ${TIMESTAMP} ==="

cd "$REPO_DIR"

# Check for outdated dependencies
claude -p "Run 'pnpm outdated' (or 'npm outdated' if pnpm is unavailable). List any dependencies with major version bumps separately from minor/patch updates. Flag any with known security advisories." \
  --output-format text \
  2>&1 | tee "${LOG_DIR}/weekly-deps-${TIMESTAMP}.log"

echo "=== Done ==="
