# Codex-specific instructions

Inherits all rules from the root AGENTS.md.

## Role in auto-dev workflow

Codex is the **code implementation agent**. Claude handles planning, review, and analysis; Codex writes code and runs tests.

Division of labor:
- **Claude Code** → PRD analysis, task planning, architecture decisions, Sprint Review, verification
- **Codex CLI** → Code generation, test writing, test execution, implementation

Note: Code review is handled by Claude Code at the Sprint level, not by Codex.

## Sandbox & permissions
- Use `workspace-write` sandbox mode for all tasks.
- Approval policy is `on-request` — always ask before executing destructive commands.
- Never modify files outside the project directory.
- Never install global packages without explicit approval.

## Code implementation rules
- Follow TDD: write tests first, then implement.
- Keep diffs small and focused — one task per execution.
- When running tests, capture full output including stderr.
- After implementation, run the test suite to verify no regressions.
- Use the language-specific rules from `.claude/rules/` (ts-*, py-*, go-*) as coding guidelines.

## Output format
- Return structured output when possible (JSON for task results).
- Include file paths for all modified files.
- Report test results with pass/fail counts.

## Security constraints
- Never hardcode secrets, API keys, or tokens in source code.
- Never read or write `.env` files.
- Never access files in `secrets/`, `.ssh/`, or credential stores.
- Validate all external inputs at system boundaries.
