# CLAUDE.md

@AGENTS.md

## Claude-specific workflow
- For non-trivial work: explore -> plan -> edit -> test.
- Prefer editing existing files over creating new ones.
- Keep summaries short; show changed files, commands, and test results.
- Use ultrathink for complex architectural decisions.

## Output preferences
- Use Chinese for commit messages and comments.
- Code and variable names in English.
- Configuration file comments in English.

## Safety reminders
- Never read or write .env files — permissions.deny will block it, but don't even attempt.
- Always run `npx ecc-agentshield scan` after modifying any file in `.claude/` or `hooks/`.
- When in doubt about a destructive operation, ask the user first.
