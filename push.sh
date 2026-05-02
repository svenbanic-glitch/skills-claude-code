#!/bin/bash
cd /workspace/.claude/skills
git add .
if git diff --cached --quiet; then
    echo "Nothing to commit"
    exit 0
fi
COMMIT_MSG="${1:-Update skills}"
git commit -m "$COMMIT_MSG"
git push origin main
echo "✓ Pushed: $COMMIT_MSG"
