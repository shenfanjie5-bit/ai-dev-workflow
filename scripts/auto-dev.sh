#!/usr/bin/env bash
set -euo pipefail
#
# auto-dev.sh — AI-Assisted Autonomous Development Orchestrator
#
# Reads requirement documents from an input directory, breaks them into tasks,
# and uses Claude Code (non-interactive mode) to implement each task with TDD.
#
# Usage:
#   ./scripts/auto-dev.sh --project my-app --input ./input/
#   ./scripts/auto-dev.sh --project my-app --input ./input/ --stack nextjs-ts --skip-push
#   ./scripts/auto-dev.sh --project my-app --input ./input/ --auto-confirm --max-retries 5
#

# Resolve script directory and source modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/scaffold.sh"
source "$LIB_DIR/plan.sh"
source "$LIB_DIR/execute.sh"
source "$LIB_DIR/verify.sh"

WORKFLOW_ROOT="$(get_workflow_root)"

# ── Defaults ──────────────────────────────────────────
PROJECT=""
INPUT_DIR=""
STACK="nextjs-ts"
OUTPUT_DIR=""
SKIP_SCAFFOLD=false
SKIP_PUSH=false
AUTO_CONFIRM=false
MAX_RETRIES=3

# ── Usage ─────────────────────────────────────────────
usage() {
  cat << 'EOF'
auto-dev — AI-Assisted Autonomous Development Orchestrator

Usage:
  ./scripts/auto-dev.sh --project NAME --input DIR [options]

Required:
  --project NAME       Project name (used for directory and GitHub repo)
  --input DIR          Directory containing requirement documents (.md, .yaml, .json, .txt)

Options:
  --stack STACK         Tech stack preset (default: nextjs-ts)
                        Supported: nextjs-ts, python-fastapi, go-gin
  --output DIR          Output parent directory (default: parent of ai-dev-workflow)
  --skip-scaffold       Skip Phase 1 (project already initialized)
  --skip-push           Don't create GitHub repo or push
  --auto-confirm        Skip task list confirmation prompt
  --max-retries N       Max retry attempts per task (default: 3)
  -h, --help            Show this help message

Workflow:
  Phase 1: Scaffold    Initialize project + copy governance configs
  Phase 2: Plan        Analyze requirements → generate tasks.json
  Phase 3: Execute     Implement each task with TDD (test first, then code)
  Phase 4: Verify      Build + test + lint + security scan + push

Example:
  # Create a new Next.js project from requirements
  ./scripts/auto-dev.sh \
    --project quantfi-dashboard \
    --input ./input/ \
    --stack nextjs-ts

  # Resume after fixing failed tasks (skip scaffold)
  ./scripts/auto-dev.sh \
    --project quantfi-dashboard \
    --input ./input/ \
    --skip-scaffold

EOF
  exit 0
}

# ── Parse arguments ───────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)      PROJECT="$2"; shift 2 ;;
    --input)        INPUT_DIR="$2"; shift 2 ;;
    --stack)        STACK="$2"; shift 2 ;;
    --output)       OUTPUT_DIR="$2"; shift 2 ;;
    --skip-scaffold) SKIP_SCAFFOLD=true; shift ;;
    --skip-push)    SKIP_PUSH=true; shift ;;
    --auto-confirm) AUTO_CONFIRM=true; shift ;;
    --max-retries)  MAX_RETRIES="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *)              log_error "Unknown option: $1"; usage ;;
  esac
done

# ── Validate required arguments ──────────────────────
if [[ -z "$PROJECT" ]]; then
  log_error "--project is required"
  usage
fi

if [[ -z "$INPUT_DIR" ]]; then
  log_error "--input is required"
  usage
fi

# Resolve paths
INPUT_DIR="$(cd "$INPUT_DIR" 2>/dev/null && pwd)" || { log_error "Input directory not found: $INPUT_DIR"; exit 1; }
[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="$(dirname "$WORKFLOW_ROOT")"
PROJECT_DIR="${OUTPUT_DIR}/${PROJECT}"

# ── Banner ────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   auto-dev · AI Development Orchestrator  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Project:     $PROJECT"
echo "  Stack:       $STACK"
echo "  Input:       $INPUT_DIR"
echo "  Output:      $PROJECT_DIR"
echo "  Retries:     $MAX_RETRIES"
echo ""

# ── Pre-flight checks ────────────────────────────────
ensure_deps || exit 1

# ── Phase 1: Scaffold ────────────────────────────────
if [[ "$SKIP_SCAFFOLD" != "true" ]]; then
  run_scaffold "$PROJECT" "$STACK" "$OUTPUT_DIR" "$WORKFLOW_ROOT" || exit 1
else
  log_info "Skipping scaffold (--skip-scaffold)"
  if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "Project directory not found: $PROJECT_DIR"
    exit 1
  fi
fi

# ── Phase 2: Plan ────────────────────────────────────
run_plan "$PROJECT_DIR" "$INPUT_DIR" "$AUTO_CONFIRM" || exit 1

# ── Phase 3: Execute ─────────────────────────────────
run_execute "$PROJECT_DIR" "$MAX_RETRIES"

# ── Phase 4: Verify ──────────────────────────────────
run_verify "$PROJECT_DIR" "$PROJECT" "$SKIP_PUSH"
