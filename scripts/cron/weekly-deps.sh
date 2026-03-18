#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/weekly-deps-${TIMESTAMP}.log"

echo "=== Weekly Dependency Check: ${TIMESTAMP} ===" | tee "$LOG_FILE"

cd "$REPO_DIR"

# ── Detect package manager and check outdated deps ──────
check_node_deps() {
  local pkg_manager="$1"
  echo "" | tee -a "$LOG_FILE"
  echo "--- Node.js Dependencies (${pkg_manager}) ---" | tee -a "$LOG_FILE"

  # Outdated packages
  echo "Checking outdated packages..." | tee -a "$LOG_FILE"
  ${pkg_manager} outdated 2>&1 | tee -a "$LOG_FILE" || true

  # Security audit
  echo "" | tee -a "$LOG_FILE"
  echo "Running security audit..." | tee -a "$LOG_FILE"
  ${pkg_manager} audit 2>&1 | tee -a "$LOG_FILE" || true
}

check_python_deps() {
  echo "" | tee -a "$LOG_FILE"
  echo "--- Python Dependencies ---" | tee -a "$LOG_FILE"

  if command -v pip >/dev/null 2>&1; then
    pip list --outdated 2>&1 | tee -a "$LOG_FILE" || true
    pip-audit 2>&1 | tee -a "$LOG_FILE" || true
  elif command -v poetry >/dev/null 2>&1; then
    poetry show --outdated 2>&1 | tee -a "$LOG_FILE" || true
  fi
}

check_go_deps() {
  echo "" | tee -a "$LOG_FILE"
  echo "--- Go Dependencies ---" | tee -a "$LOG_FILE"

  if [[ -f "go.mod" ]]; then
    go list -m -u all 2>&1 | tee -a "$LOG_FILE" || true
    govulncheck ./... 2>&1 | tee -a "$LOG_FILE" || true
  fi
}

# ── Auto-detect project type and run checks ─────────────
CHECKS_RUN=0

if [[ -f "pnpm-lock.yaml" ]]; then
  check_node_deps "pnpm"
  CHECKS_RUN=$((CHECKS_RUN + 1))
elif [[ -f "package-lock.json" ]]; then
  check_node_deps "npm"
  CHECKS_RUN=$((CHECKS_RUN + 1))
elif [[ -f "yarn.lock" ]]; then
  check_node_deps "yarn"
  CHECKS_RUN=$((CHECKS_RUN + 1))
fi

if [[ -f "requirements.txt" || -f "pyproject.toml" || -f "Pipfile" ]]; then
  check_python_deps
  CHECKS_RUN=$((CHECKS_RUN + 1))
fi

if [[ -f "go.mod" ]]; then
  check_go_deps
  CHECKS_RUN=$((CHECKS_RUN + 1))
fi

if [[ $CHECKS_RUN -eq 0 ]]; then
  echo "[INFO] No recognized dependency files found in ${REPO_DIR}" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Weekly Dependency Check Complete: ${CHECKS_RUN} stack(s) checked ===" | tee -a "$LOG_FILE"
