#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="ai-dev"

# Kill existing session if present
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Create new session with Claude Code window
tmux new-session -d -s "$SESSION_NAME" -n "claude" -c "$REPO_DIR"
tmux send-keys -t "$SESSION_NAME:claude" "claude" Enter

# Create Codex window
tmux new-window -t "$SESSION_NAME" -n "codex" -c "$REPO_DIR"
tmux send-keys -t "$SESSION_NAME:codex" "codex" Enter

# Create a general shell window
tmux new-window -t "$SESSION_NAME" -n "shell" -c "$REPO_DIR"

# Select first window
tmux select-window -t "$SESSION_NAME:claude"

echo "tmux session '$SESSION_NAME' created with 3 windows: claude, codex, shell"
echo "Attach with: tmux attach -t $SESSION_NAME"
