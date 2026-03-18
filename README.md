# AI-Assisted Development Workflow

> Claude Code + Codex CLI + ECC + Codex Review — subscription-only, zero API cost.

A production-ready configuration repository that integrates multiple AI coding agents into a unified, security-governed development workflow. Designed for individual developers using Claude Pro/Max and ChatGPT Plus/Pro subscriptions.

## Why This Exists

Using AI agents for coding without guardrails is risky: agents can read `.env` files, execute dangerous shell commands, or commit untested code. Meanwhile, solo developers lack the second pair of eyes that team code review provides.

This repo solves both problems with a **four-layer architecture**:

```
+---------------------------------------------------+
|  PR Review     — Codex Review (@codex review)      |
+---------------------------------------------------+
|  Governance    — ECC (Rules, Hooks, Skills, Shield) |
+---------------------------------------------------+
|  Execution     — Claude Code CLI  |  Codex CLI     |
+---------------------------------------------------+
|  Rules         — AGENTS.md + CLAUDE.md + .claude/   |
+---------------------------------------------------+

Orchestration (non-layer, Unix-native):
  Sessions: tmux     Scheduling: crontab
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
0 2 * * *   /path/to/scripts/cron/daily-test.sh   >> logs/test.log 2>&1
0 8 * * *   /path/to/scripts/cron/daily-scan.sh   >> logs/scan.log 2>&1
0 9 * * 1   /path/to/scripts/cron/weekly-deps.sh  >> logs/deps.log 2>&1
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

- **Claude Code** — code analysis, architecture planning, complex reasoning
- **Codex CLI** — code generation, test execution, refactoring
- Both use **subscription login only** (no `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`)

### Layer 3: Governance (ECC)

[Everything Claude Code](https://github.com/anthropics/ecc) provides:

- **29 Skills** — API design, TDD workflow, security review, etc.
- **24 Rules** — Common (9) + TypeScript (5) + Python (5) + Go (5)
- **AgentShield** — 102-rule security scanner for agent configurations
- **Hook Profile** — `minimal` (default) &rarr; `standard` &rarr; `strict`

### Layer 4: PR Review (Codex GitHub Review)

- Triggered manually via `@codex review` in PR comments (ADR-003)
- Review behavior driven by `AGENTS.md` Review guidelines
- P0/P1 severity definitions ensure high signal-to-noise ratio

## Security Model

Defense in depth with four layers:

```
Layer 1: permissions.deny        (hard block, cannot fail-open)
         Read .env / .ssh / secrets    blocked
         Write .env                    blocked
         Bash curl / wget / sudo / rm -rf   blocked

Layer 2: ECC PreToolUse Hooks    (can block, may fail-open)
         Custom validation rules before tool execution

Layer 3: AgentShield Scan        (post-hoc audit)
         102 rules: secrets, permissions, hooks, MCP, agents

Layer 4: Codex Review            (PR-level gate)
         P0: hardcoded secrets, auth regression  -> block merge
         P1: missing tests, console.log          -> flag for fix
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
|   +-- agents/
|       +-- reviewer.toml         # Codex Review agent config
|
+-- hooks/
|   +-- hooks.json                # ECC Hook definitions
|
+-- scripts/
|   +-- start-sessions.sh         # tmux session launcher
|   +-- cron/
|       +-- daily-test.sh         # Regression tests (daily 2:00)
|       +-- daily-scan.sh         # TODO/FIXME scan (daily 8:00)
|       +-- weekly-deps.sh        # Dependency drift (Mon 9:00)
|
+-- logs/                         # cron output (gitignored)
```

## Development Workflow

### Daily Flow: Code &rarr; Commit &rarr; PR &rarr; Review

```
1. Developer opens tmux session
2. Claude Code reads AGENTS.md + CLAUDE.md + rules/
3. ECC Hooks intercept each tool call (deny-list enforced)
4. Code changes -> git commit -> push to feature branch
5. Open PR -> comment @codex review
6. Codex Review checks against AGENTS.md Review guidelines
7. Fix flagged issues -> merge
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
| Daily 08:00 | `daily-scan.sh` | Scan for TODO/FIXME and failing tests |
| Monday 09:00 | `weekly-deps.sh` | Check for outdated dependencies |

All scripts use `claude -p` (non-interactive mode) and output to `logs/`.

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
# Phase 2: Plan    — Claude analyzes PRD → tasks.json
# Phase 3: Execute — TDD loop per task (test first → code → verify)
# Phase 4: Verify  — build + test + lint + security scan + push
```

Supported stacks: `nextjs-ts` (default), `python-fastapi`, `go-gin`. Run `--help` for full usage.

## Health Checks

| Layer | Command | Expected |
|-------|---------|----------|
| Rules | `head -5 AGENTS.md` | File title + Setup commands visible |
| Execution | `claude --version && codex --version` | Version numbers, no auth errors |
| Governance | `npx ecc-agentshield scan` | No Critical findings |
| Review | `@codex review` on a test PR | Review response received |

## Roadmap

### Phase 1: Foundation (Week 1) &check;
- CLI installation & subscription login
- AGENTS.md + CLAUDE.md + settings.json security baseline
- ECC Core profile + AgentShield first scan
- Codex Review configuration
- tmux + crontab scripts

### Phase 2: Daily Usage (Weeks 2-4)
- Tune Review guidelines based on real feedback
- Verify crontab stability
- Upgrade Hook profile: minimal &rarr; standard
- Add project-specific rules as needed

### Phase 3: Deep Integration (Week 5+)
- Evaluate ECC continuous-learning
- Consider strict Hook profile
- Track Claude Code Review availability for individual subscriptions

## Key Design Decisions

| ADR | Decision | Rationale |
|-----|----------|-----------|
| ADR-001 | Remove AionUi, use tmux + crontab | Lighter, more reliable, zero extra dependencies |
| ADR-002 | ECC Core profile with clear must-use/optional boundary | Avoid cognitive overload from 65+ skills |
| ADR-003 | Codex Review manual-trigger only | Preserve review quota for important PRs |
| ADR-004 | AGENTS.md as sole cross-tool contract | Single source of truth, easy tool migration |

## License

Private repository. All rights reserved.
