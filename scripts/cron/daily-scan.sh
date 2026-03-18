#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/daily-scan-${TIMESTAMP}.log"

echo "=== Daily Code Scan: ${TIMESTAMP} ===" | tee "$LOG_FILE"

cd "$REPO_DIR"

# ── 1. Scan for TODO/FIXME comments ────────────────────
echo "" | tee -a "$LOG_FILE"
echo "--- TODO/FIXME Scan ---" | tee -a "$LOG_FILE"
TODO_COUNT=0
FIXME_COUNT=0

# Search across common source file types
for EXT in ts tsx js jsx py go rs; do
  MATCHES=$(grep -rn --include="*.${EXT}" -E '\b(TODO|FIXME|HACK|XXX)\b' . 2>/dev/null || true)
  if [[ -n "$MATCHES" ]]; then
    echo "$MATCHES" | tee -a "$LOG_FILE"
    TODO_COUNT=$((TODO_COUNT + $(echo "$MATCHES" | grep -c 'TODO' || true)))
    FIXME_COUNT=$((FIXME_COUNT + $(echo "$MATCHES" | grep -c 'FIXME' || true)))
  fi
done

echo "" | tee -a "$LOG_FILE"
echo "Found: ${TODO_COUNT} TODO(s), ${FIXME_COUNT} FIXME(s)" | tee -a "$LOG_FILE"

# ── 2. Scan for .skip / .only in test files ─────────────
echo "" | tee -a "$LOG_FILE"
echo "--- Test Skip/Only Scan ---" | tee -a "$LOG_FILE"
SKIP_MATCHES=$(grep -rn --include="*.test.*" --include="*.spec.*" -E '\.(skip|only)\b' . 2>/dev/null || true)
if [[ -n "$SKIP_MATCHES" ]]; then
  echo "[WARN] Found .skip or .only in test files:" | tee -a "$LOG_FILE"
  echo "$SKIP_MATCHES" | tee -a "$LOG_FILE"
else
  echo "No .skip or .only found in test files." | tee -a "$LOG_FILE"
fi

# ── 3. Check for console.log in non-test source files ───
echo "" | tee -a "$LOG_FILE"
echo "--- Console.log Leak Scan ---" | tee -a "$LOG_FILE"
CONSOLE_MATCHES=$(grep -rn --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --exclude-dir="node_modules" --exclude-dir=".next" \
  -E '\bconsole\.(log|debug)\b' . 2>/dev/null | grep -v '\.test\.' | grep -v '\.spec\.' | grep -v '__tests__' || true)
if [[ -n "$CONSOLE_MATCHES" ]]; then
  echo "[WARN] Found console.log/debug in production code:" | tee -a "$LOG_FILE"
  echo "$CONSOLE_MATCHES" | tee -a "$LOG_FILE"
else
  echo "No console.log/debug in production code." | tee -a "$LOG_FILE"
fi

# ── 4. Summary ──────────────────────────────────────────
echo "" | tee -a "$LOG_FILE"
WARNINGS=0
[[ -n "${SKIP_MATCHES:-}" ]] && WARNINGS=$((WARNINGS + 1))
[[ -n "${CONSOLE_MATCHES:-}" ]] && WARNINGS=$((WARNINGS + 1))
[[ $FIXME_COUNT -gt 0 ]] && WARNINGS=$((WARNINGS + 1))

echo "=== Scan Complete: ${WARNINGS} warning(s), ${TODO_COUNT} TODO(s), ${FIXME_COUNT} FIXME(s) ===" | tee -a "$LOG_FILE"
