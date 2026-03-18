#!/usr/bin/env bash
# common.sh — Shared functions for auto-dev orchestrator

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_phase()   { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; echo -e "${CYAN}  Phase: $*${NC}"; echo -e "${CYAN}══════════════════════════════════════${NC}\n"; }

# Run claude in non-interactive mode with logging
# Usage: run_claude "prompt" [output_file]
run_claude() {
  local prompt="$1"
  local output_file="${2:-}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)

  if [[ -n "$output_file" ]]; then
    claude -p "$prompt" --output-format text 2>&1 | tee "$output_file"
  else
    claude -p "$prompt" --output-format text 2>&1
  fi
}

# Run claude and capture output to variable
# Usage: result=$(run_claude_capture "prompt")
run_claude_capture() {
  local prompt="$1"
  claude -p "$prompt" --output-format text 2>&1
}

# Check required dependencies
ensure_deps() {
  local missing=()

  command -v claude >/dev/null 2>&1 || missing+=("claude")
  command -v git    >/dev/null 2>&1 || missing+=("git")
  command -v pnpm   >/dev/null 2>&1 || missing+=("pnpm")
  command -v gh     >/dev/null 2>&1 || missing+=("gh")
  command -v jq     >/dev/null 2>&1 || missing+=("jq")

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing[*]}"
    log_error "Install them before running auto-dev."
    return 1
  fi

  log_success "All dependencies available: claude, git, pnpm, gh, jq"
}

# Get the root directory of ai-dev-workflow
get_workflow_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Read all files from input directory and concatenate content
# Usage: read_input_docs "/path/to/input"
read_input_docs() {
  local input_dir="$1"
  local content=""

  if [[ ! -d "$input_dir" ]]; then
    log_error "Input directory not found: $input_dir"
    return 1
  fi

  local file_count=0
  for f in "$input_dir"/*.md "$input_dir"/*.yaml "$input_dir"/*.yml "$input_dir"/*.json "$input_dir"/*.txt; do
    [[ -f "$f" ]] || continue
    content+="
--- FILE: $(basename "$f") ---
$(cat "$f")

"
    file_count=$((file_count + 1))
  done

  if [[ $file_count -eq 0 ]]; then
    log_error "No requirement files found in $input_dir (supports: .md, .yaml, .yml, .json, .txt)"
    return 1
  fi

  log_info "Read $file_count requirement file(s) from $input_dir"
  echo "$content"
}

# Parse tasks.json and return task count
# Usage: task_count=$(get_task_count "/path/to/tasks.json")
get_task_count() {
  local tasks_file="$1"
  jq '.tasks | length' "$tasks_file"
}

# Get task field by index
# Usage: title=$(get_task_field "/path/to/tasks.json" 0 "title")
get_task_field() {
  local tasks_file="$1"
  local index="$2"
  local field="$3"
  jq -r ".tasks[$index].$field" "$tasks_file"
}

# Print a summary report
print_report() {
  local project="$1"
  local total="$2"
  local succeeded="$3"
  local failed="$4"
  local skipped="$5"

  echo ""
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo -e "${CYAN}  Auto-Dev Complete: $project${NC}"
  echo -e "${CYAN}══════════════════════════════════════${NC}"
  echo ""
  echo -e "  Total tasks:     $total"
  echo -e "  ${GREEN}Succeeded:       $succeeded${NC}"
  [[ "$failed" -gt 0 ]]  && echo -e "  ${RED}Failed:          $failed${NC}"
  [[ "$skipped" -gt 0 ]] && echo -e "  ${YELLOW}Skipped:         $skipped${NC}"
  echo ""
}
