#!/usr/bin/env bash
# verify.sh — Phase 4: Full verification and push

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Run full verification suite
# Usage: run_verify "$PROJECT_DIR" "$PROJECT_NAME" "$SKIP_PUSH"
run_verify() {
  local project_dir="$1"
  local project_name="$2"
  local skip_push="${3:-false}"

  log_phase "4 — Verify"

  cd "$project_dir"

  local checks_passed=0
  local checks_failed=0

  # 1. Build check
  log_info "[1/5] Build check..."
  if pnpm build >/dev/null 2>&1; then
    log_success "Build passed"
    checks_passed=$((checks_passed + 1))
  else
    log_error "Build failed"
    checks_failed=$((checks_failed + 1))
  fi

  # 2. Type check
  log_info "[2/5] Type check..."
  if pnpm typecheck >/dev/null 2>&1; then
    log_success "Type check passed"
    checks_passed=$((checks_passed + 1))
  else
    log_warn "Type check failed (non-blocking)"
    checks_failed=$((checks_failed + 1))
  fi

  # 3. Lint
  log_info "[3/5] Lint check..."
  if pnpm lint >/dev/null 2>&1; then
    log_success "Lint passed"
    checks_passed=$((checks_passed + 1))
  else
    log_warn "Lint failed (non-blocking)"
    checks_failed=$((checks_failed + 1))
  fi

  # 4. Tests
  log_info "[4/5] Test suite..."
  if pnpm test >/dev/null 2>&1; then
    log_success "Tests passed"
    checks_passed=$((checks_passed + 1))
  else
    log_warn "Tests failed (non-blocking)"
    checks_failed=$((checks_failed + 1))
  fi

  # 5. AgentShield scan
  log_info "[5/5] AgentShield security scan..."
  local scan_result
  scan_result=$(npx ecc-agentshield@1.3.0 scan 2>&1)
  local critical_count
  critical_count=$(echo "$scan_result" | grep -o '[0-9]* critical' | head -1 | grep -o '[0-9]*' || echo "0")
  if [[ "$critical_count" == "0" || -z "$critical_count" ]]; then
    log_success "AgentShield: no critical findings"
    checks_passed=$((checks_passed + 1))
  else
    log_error "AgentShield: ${critical_count} critical finding(s)"
    checks_failed=$((checks_failed + 1))
  fi

  echo ""
  log_info "Verification: ${checks_passed}/5 checks passed, ${checks_failed}/5 failed"

  # Push to GitHub
  if [[ "$skip_push" != "true" ]]; then
    log_info "Creating GitHub repository..."
    if gh repo create "$project_name" --private --source=. --push 2>&1; then
      log_success "Pushed to GitHub: https://github.com/$(gh api user -q '.login')/${project_name}"
    else
      log_error "Failed to create/push GitHub repo"
    fi
  else
    log_info "Skipping GitHub push (--skip-push)"
  fi

  # Print final report
  local total="${AUTODEV_TOTAL:-0}"
  local succeeded="${AUTODEV_SUCCEEDED:-0}"
  local failed="${AUTODEV_FAILED:-0}"
  local skipped="${AUTODEV_SKIPPED:-0}"

  print_report "$project_name" "$total" "$succeeded" "$failed" "$skipped"

  echo "  Verification:    ${checks_passed}/5 passed"
  echo "  Logs:            ${project_dir}/logs/"
  [[ -f "${project_dir}/tasks.json" ]] && echo "  Task plan:       ${project_dir}/tasks.json"
  echo ""

  if [[ $checks_failed -gt 0 || $failed -gt 0 ]]; then
    log_warn "Some checks or tasks failed. Review logs for details."
    return 1
  fi

  log_success "All done! Project is ready."
}
