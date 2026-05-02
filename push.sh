#!/bin/bash
cd /workspace/.claude/skills

# Mirror agents from /workspace/.claude/agents/ into the repo so they get pushed.
# Agents must live at /workspace/.claude/agents/ for Claude Code to find them;
# the repo keeps a synced copy under skills/agents/.
if [ -d /workspace/.claude/agents ]; then
    mkdir -p ./agents
    rsync -a --delete \
        --include="*.md" --exclude="*" \
        /workspace/.claude/agents/ ./agents/
fi

git add .
if git diff --cached --quiet; then
    echo "Nothing to commit"
    exit 0
fi
COMMIT_MSG="${1:-Update skills}"
git commit -m "$COMMIT_MSG"
git push origin main
echo "✓ Pushed: $COMMIT_MSG"
