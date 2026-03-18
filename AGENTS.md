# AGENTS.md — AI 辅助开发工作流共享规范

## Setup commands
- Install deps: `pnpm install`
- Dev: `pnpm dev`
- Test: `pnpm test`
- Lint: `pnpm lint`
- Type check: `pnpm typecheck`
- Security scan: `npx ecc-agentshield scan`

## Working agreements
- Keep diffs small and reversible.
- Ask before adding new production dependencies.
- After changing TS/JS, run the nearest affected tests.
- Never commit directly to main; always use feature branches.
- Commit messages follow Conventional Commits format.
- All configuration changes must be validated by AgentShield scan before commit.

## Architecture notes
- This repo manages the AI-assisted development workflow itself.
- Shared rules live in AGENTS.md (this file) — the single source of truth.
- Claude-specific config lives in `.claude/` — do not modify for Codex compatibility.
- Codex-specific config lives in `.codex/` — do not modify for Claude compatibility.
- Cron scripts live in `scripts/cron/` and are scheduled via system crontab.
- ECC skills live in `.agents/skills/`.
- Hook definitions live in `hooks/hooks.json`.

## Review guidelines
- Treat auth/session regressions as P0.
- Treat data-loss or migration issues as P0.
- Treat any hardcoded secrets or API keys as P0.
- Treat missing tests for changed business logic as P1.
- Treat console.log left in production code as P1.
- Treat typos in user-facing strings as P1.
- Treat changes to permissions.deny without explicit justification as P0.
- Treat removal of security hooks without replacement as P0.
