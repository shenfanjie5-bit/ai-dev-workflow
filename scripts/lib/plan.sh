#!/usr/bin/env bash
# plan.sh — Phase 2: Analyze requirements and generate task list

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Analyze requirements and produce tasks.json
# Usage: run_plan "$PROJECT_DIR" "$INPUT_DIR" "$AUTO_CONFIRM"
run_plan() {
  local project_dir="$1"
  local input_dir="$2"
  local auto_confirm="${3:-false}"
  local tasks_file="${project_dir}/tasks.json"
  local log_dir="${project_dir}/logs"

  log_phase "2 — Plan"

  mkdir -p "$log_dir"

  # Read all requirement documents
  local docs
  docs=$(read_input_docs "$input_dir")
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Ask Claude to analyze requirements and produce tasks.json
  log_info "Analyzing requirements with Claude..."

  cd "$project_dir"

  local prompt
  prompt=$(cat << PLANEOF
You are a senior software architect. Analyze the following requirement documents and produce a structured task list in JSON format.

REQUIREMENTS:
${docs}

OUTPUT FORMAT (strict JSON, no markdown fences):
{
  "project": "PROJECT_NAME",
  "tasks": [
    {
      "id": 1,
      "title": "Short task title in Chinese",
      "description": "Detailed implementation description including what files to create/modify, what dependencies to install, and what tests to write. Be specific enough that another AI agent can implement this without ambiguity.",
      "depends_on": []
    }
  ]
}

RULES:
1. Break down into 5-15 small, independently testable tasks.
2. Order tasks by dependency (infrastructure first, then features, then polish).
3. Each task should be completable in a single Claude session.
4. Include database setup, API endpoints, UI components, and tests as separate tasks.
5. First task should always be project infrastructure (database connection, auth setup, etc).
6. Last task should be integration testing and polish.
7. Each description must mention what tests to write.
8. Output ONLY valid JSON, no explanation text before or after.
PLANEOF
  )

  local result
  result=$(run_claude_capture "$prompt")

  # Extract JSON from result (handle possible markdown fences)
  local json_content
  json_content=$(echo "$result" | sed -n '/^{/,/^}/p' | head -1)

  if [[ -z "$json_content" ]]; then
    # Try to extract from markdown code block
    json_content=$(echo "$result" | sed -n '/```json/,/```/p' | sed '1d;$d')
  fi

  if [[ -z "$json_content" ]]; then
    # Last resort: save full output and try jq
    echo "$result" > "$tasks_file"
    if ! jq '.' "$tasks_file" >/dev/null 2>&1; then
      log_error "Failed to generate valid tasks.json"
      log_error "Claude output saved to: ${log_dir}/plan-raw.log"
      echo "$result" > "${log_dir}/plan-raw.log"
      return 1
    fi
  else
    echo "$json_content" > "$tasks_file"
  fi

  # Validate JSON
  if ! jq '.' "$tasks_file" >/dev/null 2>&1; then
    log_error "Generated tasks.json is not valid JSON"
    echo "$result" > "${log_dir}/plan-raw.log"
    return 1
  fi

  local task_count
  task_count=$(get_task_count "$tasks_file")
  log_success "Generated ${task_count} tasks → tasks.json"

  # Print task list
  echo ""
  echo "Task List:"
  echo "─────────────────────────────────────"
  for i in $(seq 0 $((task_count - 1))); do
    local tid title
    tid=$(get_task_field "$tasks_file" "$i" "id")
    title=$(get_task_field "$tasks_file" "$i" "title")
    echo "  [$tid] $title"
  done
  echo "─────────────────────────────────────"
  echo ""

  # Confirm with user unless --auto-confirm
  if [[ "$auto_confirm" != "true" ]]; then
    log_info "Review the task list above."
    read -r -p "Proceed with execution? [Y/n] " confirm
    case "$confirm" in
      [nN]*) log_warn "Aborted by user."; return 1 ;;
    esac
  fi

  log_success "Plan confirmed. Ready for execution."
}
