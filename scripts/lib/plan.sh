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
  "sprints": [
    {
      "id": 1,
      "name": "Sprint name describing the functional module",
      "tasks": [
        {
          "id": 1,
          "title": "Short task title in Chinese",
          "description": "Detailed implementation description including what files to create/modify, what dependencies to install, and what tests to write. Be specific enough that another AI agent can implement this without ambiguity.",
          "depends_on": []
        }
      ]
    }
  ]
}

RULES:
1. Break down into 5-15 small, independently testable tasks.
2. Group tasks into Sprints by functional module (3-5 tasks per Sprint).
3. Sprint 1 is always infrastructure (project setup, database, config).
4. The last Sprint is always integration testing and polish.
5. Order Sprints by dependency (infrastructure → core features → UI → polish).
6. Within each Sprint, order tasks by dependency.
7. Each task should be completable in a single Claude session.
8. Include database setup, API endpoints, UI components, and tests as separate tasks.
9. Each description must mention what tests to write.
10. Output ONLY valid JSON, no explanation text before or after.
PLANEOF
  )

  local result
  result=$(run_claude_capture "$prompt")

  # Save raw output for debugging
  echo "$result" > "${log_dir}/plan-raw.log"

  # Extract JSON: strip markdown code fences if present
  local json_content
  json_content=$(echo "$result" | sed '/^```.*$/d')
  echo "$json_content" > "$tasks_file"

  # Validate JSON
  if ! jq '.' "$tasks_file" >/dev/null 2>&1; then
    # Fallback: extract between first { and last }
    json_content=$(echo "$result" | sed -n '/^{/,/^}/p')
    echo "$json_content" > "$tasks_file"

    if ! jq '.' "$tasks_file" >/dev/null 2>&1; then
      log_error "Failed to generate valid tasks.json"
      log_error "Raw output saved to: ${log_dir}/plan-raw.log"
      return 1
    fi
  fi

  local sprint_count task_count
  sprint_count=$(jq '.sprints | length' "$tasks_file")
  task_count=$(jq '[.sprints[].tasks[]] | length' "$tasks_file")
  log_success "Generated ${task_count} tasks in ${sprint_count} sprints → tasks.json"

  # Print sprint/task list
  echo ""
  echo "Sprint Plan:"
  echo "─────────────────────────────────────"
  for s in $(seq 0 $((sprint_count - 1))); do
    local sname
    sname=$(jq -r ".sprints[$s].name" "$tasks_file")
    echo ""
    echo "  Sprint $((s + 1)): $sname"
    local stask_count
    stask_count=$(jq ".sprints[$s].tasks | length" "$tasks_file")
    for t in $(seq 0 $((stask_count - 1))); do
      local tid title
      tid=$(jq -r ".sprints[$s].tasks[$t].id" "$tasks_file")
      title=$(jq -r ".sprints[$s].tasks[$t].title" "$tasks_file")
      echo "    [$tid] $title"
    done
  done
  echo ""
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
