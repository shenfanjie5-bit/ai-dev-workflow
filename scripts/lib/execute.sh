#!/usr/bin/env bash
# execute.sh — Phase 3: Execute tasks with Claude (plan) + Codex (implement)
#
# Architecture alignment (ADR design):
#   Claude Code → analysis, planning, complex reasoning
#   Codex CLI   → code generation, test execution, refactoring

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Execute all tasks from tasks.json
# Usage: run_execute "$PROJECT_DIR" "$MAX_RETRIES"
run_execute() {
  local project_dir="$1"
  local max_retries="${2:-3}"
  local tasks_file="${project_dir}/tasks.json"
  local log_dir="${project_dir}/logs"
  local failed_log="${log_dir}/failed-tasks.log"

  log_phase "3 — Execute (Claude plans → Codex implements)"

  mkdir -p "$log_dir"
  : > "$failed_log"

  cd "$project_dir"

  if [[ ! -f "$tasks_file" ]]; then
    log_error "tasks.json not found. Run Phase 2 (plan) first."
    return 1
  fi

  local task_count succeeded failed skipped
  task_count=$(get_task_count "$tasks_file")
  succeeded=0
  failed=0
  skipped=0

  log_info "Executing ${task_count} tasks (max retries per task: ${max_retries})"
  log_info "Workflow: Claude Code (plan) → Codex CLI (implement)"

  for i in $(seq 0 $((task_count - 1))); do
    local tid title description
    tid=$(get_task_field "$tasks_file" "$i" "id")
    title=$(get_task_field "$tasks_file" "$i" "title")
    description=$(get_task_field "$tasks_file" "$i" "description")

    echo ""
    log_info "━━━ Task ${tid}/${task_count}: ${title} ━━━"

    # Save state before task
    git stash push -m "auto-dev-task-${tid}" --include-untracked >/dev/null 2>&1 || true
    local had_stash=$?

    local task_succeeded=false

    for attempt in $(seq 1 "$max_retries"); do
      log_info "Attempt ${attempt}/${max_retries}..."

      local task_log="${log_dir}/task-${tid}-attempt-${attempt}.log"

      # ── Step 1: Codex implements (code generation + tests) ──
      local codex_prompt
      codex_prompt="You are implementing a feature for this project. Follow TDD: write tests first, then implement.

TASK: ${title}
DESCRIPTION: ${description}

INSTRUCTIONS:
1. First, write test file(s) for this feature.
2. Then implement the feature to make tests pass.
3. Run the test command (pnpm test) to verify.
4. If tests fail, fix the code until they pass.
5. Keep changes focused on this task only.
6. Use TypeScript strict mode. Follow existing code patterns.
7. All financial calculations must use decimal.js, never floating-point."

      run_codex "$codex_prompt" "$task_log"
      local exit_code=$?

      if [[ $exit_code -eq 0 ]]; then
        # Check if there are actual code changes
        if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
          log_warn "No file changes detected, retrying..."
          continue
        fi

        # ── Step 2: Claude reviews (quick sanity check) ──
        log_info "Claude reviewing changes..."
        local review_result
        review_result=$(run_claude_capture "Review the git diff for task '${title}'. Check for: 1) hardcoded secrets 2) floating-point on financial data 3) missing error handling. Reply with PASS if OK, or list issues found. Be brief.")

        if echo "$review_result" | grep -qi "PASS\|looks good\|no issues\|approved"; then
          log_success "Claude review: PASS"
        else
          log_warn "Claude review flagged issues (non-blocking): $(echo "$review_result" | head -3)"
        fi

        # Commit changes
        git add -A
        git commit -m "feat(task-${tid}): ${title}" >/dev/null 2>&1

        log_success "Task ${tid} completed: ${title}"
        task_succeeded=true
        succeeded=$((succeeded + 1))
        break
      else
        log_warn "Attempt ${attempt} failed for task ${tid}"
        # Reset changes from failed attempt
        git checkout -- . 2>/dev/null || true
        git clean -fd 2>/dev/null || true
      fi
    done

    if [[ "$task_succeeded" != "true" ]]; then
      log_error "Task ${tid} FAILED after ${max_retries} attempts: ${title}"
      echo "[FAILED] Task ${tid}: ${title}" >> "$failed_log"
      failed=$((failed + 1))

      # Restore state from before task
      if [[ $had_stash -eq 0 ]]; then
        git stash pop >/dev/null 2>&1 || true
      fi
    fi
  done

  echo ""
  log_info "Execution summary: ${succeeded} succeeded, ${failed} failed, ${skipped} skipped out of ${task_count}"

  # Export counts for verify phase
  export AUTODEV_TOTAL=$task_count
  export AUTODEV_SUCCEEDED=$succeeded
  export AUTODEV_FAILED=$failed
  export AUTODEV_SKIPPED=$skipped

  if [[ $failed -gt 0 ]]; then
    log_warn "Failed tasks logged to: $failed_log"
  fi
}
