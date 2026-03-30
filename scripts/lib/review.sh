#!/usr/bin/env bash
# review.sh — Sprint Review: Claude Code comprehensive code review
#
# Called at the end of each Sprint. Reviews the cumulative diff
# against AGENTS.md P0/P1 rules. P0 issues block; P1 issues are logged.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Run Sprint Review
# Usage: run_sprint_review "$PROJECT_DIR" "$SPRINT_NUM" "$SPRINT_START_REF" "$MAX_FIX_ROUNDS"
# Returns: 0 if passed, 1 if P0 remains after max fix rounds
run_sprint_review() {
  local project_dir="$1"
  local sprint_num="$2"
  local start_ref="$3"
  local max_fix_rounds="${4:-2}"
  local log_dir="${project_dir}/logs"
  local review_log="${log_dir}/review-sprint-${sprint_num}.log"

  log_info "━━━ Sprint ${sprint_num} Review ━━━"

  mkdir -p "$log_dir"
  cd "$project_dir"

  local round=0

  while [[ $round -lt $max_fix_rounds ]]; do
    round=$((round + 1))

    # Get cumulative diff for this sprint
    local diff
    diff=$(git diff "${start_ref}..HEAD" 2>/dev/null || git diff HEAD~5 2>/dev/null || echo "")

    if [[ -z "$diff" ]]; then
      log_warn "No diff to review for Sprint ${sprint_num}"
      echo "[Sprint ${sprint_num}] No changes to review" > "$review_log"
      return 0
    fi

    log_info "Review round ${round}/${max_fix_rounds}..."

    # Claude Code comprehensive review
    local review_prompt
    review_prompt=$(cat << REVIEWEOF
You are a senior code reviewer. Review the following git diff thoroughly.

REVIEW RULES (from AGENTS.md):
P0 — MUST block (respond with P0_FOUND):
  - Hardcoded secrets, API keys, or tokens in source code
  - Auth/session regressions (missing authorization checks)
  - Data-loss or migration issues
  - SQL injection or other injection vulnerabilities
  - Changes to permissions.deny without explicit justification
  - Removal of security hooks without replacement

P1 — Flag for fix (respond with P1_FOUND):
  - Missing tests for changed business logic
  - console.log / print() left in production code
  - Typos in user-facing strings
  - .skip or .only left in test files
  - Functions exceeding 50 lines without justification
  - Float arithmetic on financial data (must use Decimal)
  - Missing input validation at system boundaries

DIFF:
${diff}

RESPONSE FORMAT (strict):
If P0 issues found, start your response with "P0_FOUND" on the first line.
If only P1 issues found, start with "P1_FOUND" on the first line.
If no issues, start with "REVIEW_PASS" on the first line.

Then list each finding as:
[P0] or [P1] file:line — description

Be specific. Include the exact file path and line number.
REVIEWEOF
    )

    local review_result
    review_result=$(run_claude_capture "$review_prompt")

    # Save review output
    echo "=== Sprint ${sprint_num} Review — Round ${round} ===" >> "$review_log"
    echo "$review_result" >> "$review_log"
    echo "" >> "$review_log"

    # Check result
    if echo "$review_result" | head -1 | grep -q "REVIEW_PASS"; then
      log_success "Sprint ${sprint_num} Review: PASS"
      return 0
    fi

    if echo "$review_result" | head -1 | grep -q "P0_FOUND"; then
      log_error "Sprint ${sprint_num} Review: P0 issues found"
      echo "$review_result" | grep '^\[P0\]' | while read -r line; do
        log_error "  $line"
      done

      # Show P1 issues too (non-blocking)
      echo "$review_result" | grep '^\[P1\]' | while read -r line; do
        log_warn "  $line"
      done

      if [[ $round -lt $max_fix_rounds ]]; then
        log_info "Attempting auto-fix via Codex (round ${round})..."

        # Extract P0 issues for fix prompt
        local p0_issues
        p0_issues=$(echo "$review_result" | grep '^\[P0\]')

        local fix_prompt
        fix_prompt="Fix the following P0 security/quality issues. Do NOT introduce new features — only fix these specific problems:

${p0_issues}

Fix each issue in the exact file and line mentioned. After fixing, run tests to verify nothing is broken."

        run_codex "$fix_prompt" "${log_dir}/fix-sprint-${sprint_num}-round-${round}.log"

        # Commit fixes
        if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
          git add -A
          git commit -m "fix(sprint-${sprint_num}): address P0 review findings (round ${round})" >/dev/null 2>&1
          log_info "Fix committed. Re-reviewing..."
        else
          log_warn "No changes from fix attempt"
        fi
      fi
    elif echo "$review_result" | head -1 | grep -q "P1_FOUND"; then
      log_warn "Sprint ${sprint_num} Review: P1 issues found (non-blocking)"
      echo "$review_result" | grep '^\[P1\]' | while read -r line; do
        log_warn "  $line"
      done
      log_info "P1 issues logged to: $review_log"
      return 0
    else
      # Ambiguous response — treat as pass with warning
      log_warn "Sprint ${sprint_num} Review: ambiguous response (treating as pass)"
      return 0
    fi
  done

  # If we exhausted fix rounds and still have P0
  log_error "Sprint ${sprint_num} Review: P0 issues remain after ${max_fix_rounds} fix rounds"
  log_error "Review log: $review_log"
  return 1
}
