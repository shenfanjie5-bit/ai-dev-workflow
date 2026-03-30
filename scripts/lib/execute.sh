#!/usr/bin/env bash
# execute.sh — Phase 3: Execute tasks by Sprint with Review Gate
#
# Architecture:
#   Codex CLI   → code generation, test execution
#   Claude Code → inline quick check (per task) + Sprint Review (per sprint)
#
# Flow per Sprint:
#   1. Execute each task (Codex implements → Claude quick check → commit)
#   2. Sprint Review (Claude comprehensive review against P0/P1 rules)
#   3. If P0 found → Codex fix → re-review (up to 2 rounds)
#   4. Tag sprint-{N}-done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/review.sh"

# Execute all sprints from tasks.json
# Usage: run_execute "$PROJECT_DIR" "$MAX_RETRIES"
run_execute() {
  local project_dir="$1"
  local max_retries="${2:-3}"
  local tasks_file="${project_dir}/tasks.json"
  local log_dir="${project_dir}/logs"
  local failed_log="${log_dir}/failed-tasks.log"

  log_phase "3 — Execute (Sprint loop + Review Gate)"

  mkdir -p "$log_dir"
  : > "$failed_log"

  cd "$project_dir"

  if [[ ! -f "$tasks_file" ]]; then
    log_error "tasks.json not found. Run Phase 2 (plan) first."
    return 1
  fi

  local sprint_count total_tasks succeeded failed skipped review_failures
  sprint_count=$(jq '.sprints | length' "$tasks_file")
  total_tasks=$(jq '[.sprints[].tasks[]] | length' "$tasks_file")
  succeeded=0
  failed=0
  skipped=0
  review_failures=0

  log_info "Executing ${total_tasks} tasks across ${sprint_count} sprints"
  log_info "Workflow: Codex (implement) → Claude (quick check) → Sprint Review"

  for s in $(seq 0 $((sprint_count - 1))); do
    local sprint_num=$((s + 1))
    local sprint_name
    sprint_name=$(jq -r ".sprints[$s].name" "$tasks_file")
    local task_count
    task_count=$(jq ".sprints[$s].tasks | length" "$tasks_file")

    echo ""
    log_phase "Sprint ${sprint_num}/${sprint_count}: ${sprint_name}"
    log_info "${task_count} tasks in this sprint"

    # Save ref before sprint starts (for sprint review diff)
    local sprint_start_ref
    sprint_start_ref=$(git rev-parse HEAD 2>/dev/null || echo "")

    # ── Execute each task in this sprint ──
    for t in $(seq 0 $((task_count - 1))); do
      local tid title description
      tid=$(jq -r ".sprints[$s].tasks[$t].id" "$tasks_file")
      title=$(jq -r ".sprints[$s].tasks[$t].title" "$tasks_file")
      description=$(jq -r ".sprints[$s].tasks[$t].description" "$tasks_file")

      echo ""
      log_info "━━━ Task ${tid}: ${title} ━━━"

      local task_succeeded=false

      for attempt in $(seq 1 "$max_retries"); do
        log_info "Attempt ${attempt}/${max_retries}..."

        local task_log="${log_dir}/task-${tid}-attempt-${attempt}.log"

        # ── Step 1: Codex implements ──
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

          # ── Step 2: Claude quick check (lightweight, non-blocking) ──
          log_info "Claude quick check..."
          local review_result
          review_result=$(run_claude_capture "Review the git diff for task '${title}'. Check for: 1) hardcoded secrets 2) SQL injection 3) missing auth checks. Reply with PASS if OK, or list issues found. Be brief.")

          if echo "$review_result" | grep -qi "PASS\|looks good\|no issues\|approved"; then
            log_success "Quick check: PASS"
          else
            log_warn "Quick check flagged issues (non-blocking): $(echo "$review_result" | head -3)"
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
          git checkout -- . 2>/dev/null || true
          git clean -fd 2>/dev/null || true
        fi
      done

      if [[ "$task_succeeded" != "true" ]]; then
        log_error "Task ${tid} FAILED after ${max_retries} attempts: ${title}"
        echo "[FAILED] Task ${tid}: ${title}" >> "$failed_log"
        failed=$((failed + 1))
      fi
    done

    # ── Sprint Review Gate ──
    if [[ -n "$sprint_start_ref" ]]; then
      run_sprint_review "$project_dir" "$sprint_num" "$sprint_start_ref" 2
      local review_exit=$?

      if [[ $review_exit -eq 0 ]]; then
        # Tag successful sprint
        git tag "sprint-${sprint_num}-done" 2>/dev/null || true
        log_success "Sprint ${sprint_num} tagged: sprint-${sprint_num}-done"
      else
        review_failures=$((review_failures + 1))
        log_error "Sprint ${sprint_num} review failed — continuing to next sprint"
      fi
    else
      log_warn "No start ref for sprint ${sprint_num}, skipping review"
    fi
  done

  echo ""
  log_info "Execution summary: ${succeeded} succeeded, ${failed} failed, ${skipped} skipped out of ${total_tasks}"
  [[ $review_failures -gt 0 ]] && log_warn "Sprint reviews with unresolved P0: ${review_failures}"

  # Export counts for verify phase
  export AUTODEV_TOTAL=$total_tasks
  export AUTODEV_SUCCEEDED=$succeeded
  export AUTODEV_FAILED=$failed
  export AUTODEV_SKIPPED=$skipped

  if [[ $failed -gt 0 ]]; then
    log_warn "Failed tasks logged to: $failed_log"
  fi
}
