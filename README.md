# AI-Assisted Development Workflow

> Claude Code + Codex CLI + ECC — subscription-only, zero API cost.

A production-ready configuration repository that integrates multiple AI coding agents into a unified, security-governed development workflow. Designed for individual developers using Claude Pro/Max and ChatGPT Plus/Pro subscriptions.

## Why This Exists

Using AI agents for coding without guardrails is risky: agents can read `.env` files, execute dangerous shell commands, or commit untested code. Meanwhile, solo developers lack the second pair of eyes that team code review provides.

This repo solves both problems with a **three-layer architecture** plus Sprint-based code review:

```
+---------------------------------------------------+
|  Governance    — ECC (Rules, Hooks, Skills, Shield) |
+---------------------------------------------------+
|  Execution     — Claude Code (plan/review)         |
|                  Codex CLI   (implement)           |
+---------------------------------------------------+
|  Rules         — AGENTS.md + CLAUDE.md + .claude/   |
+---------------------------------------------------+

Cross-cutting:
  Sprint Review  — Claude Code comprehensive review per Sprint
  Orchestration  — tmux + crontab (Unix-native)
```

## Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | 18+ | `brew install node` |
| Claude Code | latest | `npm install -g @anthropic-ai/claude-code` |
| Codex CLI | latest | `npm install -g @openai/codex` |
| tmux | any | `brew install tmux` |
| gh (GitHub CLI) | any | `brew install gh` |

### 1. Clone and Enter

```bash
git clone git@github.com:shenfanjie5-bit/ai-dev-workflow.git
cd ai-dev-workflow
```

### 2. Authenticate CLI Tools

```bash
# Claude Code — opens browser for subscription login
claude auth login

# Codex CLI — opens browser for ChatGPT subscription login
codex auth login

# GitHub CLI
gh auth login
```

### 3. Start Working

```bash
# Option A: Launch tmux session with Claude + Codex + shell windows
./scripts/start-sessions.sh
tmux attach -t ai-dev

# Option B: Use Claude Code directly
claude
```

### 4. Set Up Scheduled Tasks (Optional)

```bash
crontab -e
# Add the following (adjust paths):
0 2 * * *   /path/to/scripts/cron/daily-test.sh    >> logs/test.log 2>&1
0 6 * * *   /path/to/scripts/cron/daily-shield.sh  >> logs/shield.log 2>&1
0 8 * * *   /path/to/scripts/cron/daily-scan.sh    >> logs/scan.log 2>&1
0 9 * * 1   /path/to/scripts/cron/weekly-deps.sh   >> logs/deps.log 2>&1
```

## Architecture

### Layer 1: Rules (Pure Text Contracts)

| File | Role |
|------|------|
| `AGENTS.md` | Cross-tool shared spec (single source of truth) |
| `CLAUDE.md` | Claude Code-specific instructions (`@AGENTS.md` import) |
| `.claude/settings.json` | Permission deny-list (hard security boundary) |
| `.claude/rules/*.md` | 24 topic-specific rules (coding style, testing, security, etc.) |
| `.codex/AGENTS.md` | Codex-specific supplements |

**Key design decision (ADR-004):** `AGENTS.md` is the only cross-tool contract. Tool-specific configs are strictly isolated in their own directories.

### Layer 2: Execution (AI Agents)

- **Claude Code** — planning, analysis, complex reasoning, **Sprint Review**
- **Codex CLI** — code generation, test execution, refactoring
- Both use **subscription login only** (no `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`)

### Layer 3: Governance (ECC)

[Everything Claude Code](https://github.com/anthropics/ecc) provides:

- **29 Skills** — API design, TDD workflow, security review, etc.
- **24 Rules** — Common (9) + TypeScript (5) + Python (5) + Go (5)
- **AgentShield** — 102-rule security scanner for agent configurations
- **Hook Profile** — `minimal` (default) &rarr; `standard` &rarr; `strict`

### Sprint Review (Claude Code)

- Triggered automatically at the end of each Sprint in `auto-dev.sh`
- Reviews cumulative Sprint diff against `AGENTS.md` Review guidelines (P0/P1)
- P0 issues block the Sprint — Codex auto-fixes, then re-review (up to 2 rounds)
- P1 issues are logged but non-blocking
- Each passed Sprint is tagged `sprint-{N}-done`

## Security Model

Defense in depth with three layers plus Sprint Review:

```
Layer 1: permissions.deny        (hard block, cannot fail-open)
         Read .env / .ssh / secrets    blocked
         Write .env                    blocked
         Bash curl / wget / sudo / rm -rf   blocked

Layer 2: ECC PreToolUse Hooks    (can block, may fail-open)
         Custom validation rules before tool execution

Layer 3: AgentShield Scan        (post-hoc audit)
         102 rules: secrets, permissions, hooks, MCP, agents

Sprint Review: Claude Code       (per-Sprint gate)
         P0: hardcoded secrets, auth regression, SQL injection  -> block Sprint
         P1: missing tests, console.log, float finance          -> log only
```

## Repository Structure

```
ai-dev-workflow/
+-- AGENTS.md                     # Cross-tool shared spec
+-- CLAUDE.md                     # Claude Code instructions
+-- README.md                     # This file
+-- .gitignore
|
+-- .claude/
|   +-- settings.json             # Permission deny-list
|   +-- rules/                    # 24 rule files
|   |   +-- coding-style.md
|   |   +-- security.md
|   |   +-- testing.md
|   |   +-- git-workflow.md
|   |   +-- development-workflow.md
|   |   +-- ts-*.md               # TypeScript-specific (5)
|   |   +-- py-*.md               # Python-specific (5)
|   |   +-- go-*.md               # Go-specific (5)
|   |   +-- ...
|   +-- skills/                   # 29 ECC skills
|       +-- api-design/
|       +-- tdd-workflow/
|       +-- security-review/
|       +-- ...
|
+-- .codex/
|   +-- AGENTS.md                 # Codex-specific supplements
|   +-- config.toml               # Codex CLI config
|
+-- hooks/
|   +-- hooks.json                # ECC Hook definitions
|
+-- scripts/
|   +-- start-sessions.sh         # tmux session launcher
|   +-- lib/
|   |   +-- common.sh             # Shared functions & CLI wrappers
|   |   +-- scaffold.sh           # Phase 1: project init
|   |   +-- plan.sh               # Phase 2: PRD → tasks.json (Sprint groups)
|   |   +-- review.sh             # Sprint Review: Claude Code P0/P1 audit
|   |   +-- execute.sh            # Phase 3: Sprint loop + Review Gate
|   |   +-- verify.sh             # Phase 4: build/test/lint/scan/push
|   +-- cron/
|       +-- daily-test.sh         # Regression tests (daily 2:00)
|       +-- daily-shield.sh       # AgentShield scan (daily 6:00)
|       +-- daily-scan.sh         # TODO/FIXME scan (daily 8:00)
|       +-- weekly-deps.sh        # Dependency drift (Mon 9:00)
|
+-- logs/                         # cron output (gitignored)
```

## Development Workflow

### Daily Flow: Sprint &rarr; Review &rarr; Commit &rarr; PR

```
1. Developer opens tmux session (or runs auto-dev.sh)
2. Claude Code reads AGENTS.md + CLAUDE.md + rules/
3. ECC Hooks intercept each tool call (deny-list enforced)
4. Per Sprint: Codex implements tasks → Claude quick checks
5. Sprint Review: Claude audits cumulative diff (P0 blocks, P1 logs)
6. Tag sprint-{N}-done → push to feature branch
7. Open PR → merge (review already done at Sprint level)
```

### Feature Implementation Order

1. **Research & Reuse** — search GitHub, package registries, docs before writing
2. **Plan First** — use planner agent for complex features
3. **TDD** — write tests first (RED), implement (GREEN), refactor (IMPROVE)
4. **Code Review** — code-reviewer agent checks quality
5. **Commit & Push** — conventional commit messages, feature branches only

### Review Severity Definitions

| Level | Definition | Examples |
|-------|-----------|----------|
| **P0** | Data loss / security vulnerability / auth regression | Hardcoded secrets, migration breakage, session regression |
| **P1** | Quality red line | Missing tests, console.log in production, user-facing typos |

## Cron Tasks

| Schedule | Script | Purpose |
|----------|--------|---------|
| Daily 02:00 | `daily-test.sh` | Run regression tests, report failures |
| Daily 06:00 | `daily-shield.sh` | AgentShield security scan on workflow configs |
| Daily 08:00 | `daily-scan.sh` | Scan for TODO/FIXME, .skip/.only, console.log |
| Monday 09:00 | `weekly-deps.sh` | Check outdated deps + security audit (multi-stack) |

Scripts run directly (no `claude -p` dependency) and output to `logs/`.

## Configuration Reference

### permissions.deny (security baseline)

```json
{
  "permissions": {
    "deny": [
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/secrets/**)",
      "Read(**/.ssh/**)",
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Bash(rm -rf:*)",
      "Bash(sudo:*)",
      "Bash(chmod 777:*)",
      "Bash(> /dev/:*)",
      "Write(**/.env)",
      "Write(**/.env.*)"
    ]
  }
}
```

### ECC Hook Profiles

| Profile | When to Use | Upgrade Criteria |
|---------|-------------|-----------------|
| `minimal` | Initial setup, learning phase | Default starting point |
| `standard` | Daily development | 2 weeks without Hook false positives |
| `strict` | Sensitive code, security audits | Explicit need for maximum safety |

Set via: `export ECC_HOOK_PROFILE=minimal` in `~/.zshrc`

## Auto-Dev: Autonomous Development Orchestrator

Provide requirement documents, and `auto-dev.sh` autonomously scaffolds a project, breaks requirements into tasks, implements each with TDD, and delivers a working codebase.

```bash
# Put your PRD in input/ then run:
./scripts/auto-dev.sh --project my-app --input ./input/ --stack nextjs-ts

# Phase 1: Scaffold — init project + copy governance configs
# Phase 2: Plan    — Claude analyzes PRD → tasks.json (Sprint groups)
# Phase 3: Execute — Per-Sprint: implement tasks + Sprint Review
# Phase 4: Verify  — build + test + lint + security scan + push
```

Supported stacks: `nextjs-ts` (default), `python-fastapi`, `go-gin`. Run `--help` for full usage.

## Health Checks

| Layer | Command | Expected |
|-------|---------|----------|
| Rules | `head -5 AGENTS.md` | File title + Setup commands visible |
| Execution | `claude --version && codex --version` | Version numbers, no auth errors |
| Governance | `npx ecc-agentshield scan` | No Critical findings |
| Sprint Review | `claude -p "echo REVIEW_PASS"` | Claude responds without auth errors |

## Roadmap

### Phase 1: Foundation (Week 1) &check;
- CLI installation & subscription login
- AGENTS.md + CLAUDE.md + settings.json security baseline
- ECC Core profile + AgentShield first scan
- Sprint-based auto-dev workflow with Claude Code Review
- tmux + crontab scripts

### Phase 2: Daily Usage (Weeks 2-4)
- Tune Sprint Review P0/P1 rules based on real auto-dev runs
- Verify crontab stability
- Upgrade Hook profile: minimal &rarr; standard
- Add project-specific rules as needed
- Tune Sprint size (currently 3-5 tasks per Sprint)

### Phase 3: Deep Integration (Week 5+)
- Evaluate ECC continuous-learning
- Consider strict Hook profile
- Explore PR-level review integration (Claude Code or GitHub Actions)

## Key Design Decisions

| ADR | Decision | Rationale |
|-----|----------|-----------|
| ADR-001 | Remove AionUi, use tmux + crontab | Lighter, more reliable, zero extra dependencies |
| ADR-002 | ECC Core profile with clear must-use/optional boundary | Avoid cognitive overload from 65+ skills |
| ~~ADR-003~~ | ~~Codex Review manual-trigger only~~ | Deprecated: Codex Review doesn't read repo config; replaced by Claude Code Sprint Review (ADR-005) |
| ADR-004 | AGENTS.md as sole cross-tool contract | Single source of truth, easy tool migration |
| ADR-005 | Replace Codex Review with Claude Code Sprint Review | Codex Review ignores repo-level P0/P1 rules (tested 2026-03-30). Claude Code reviews the Sprint diff locally, consuming AGENTS.md guidelines directly. Sprint grouping gives natural review boundaries. |

## License

Private repository. All rights reserved.
