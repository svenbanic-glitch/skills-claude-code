#!/bin/bash
cd /workspace/.claude/skills

# Mirror agents from /workspace/.claude/agents/ into the repo so they get pushed.
# Agents must live at /workspace/.claude/agents/ for Claude Code to find them;
# the repo keeps a synced copy under skills/agents/.
if [ -d /workspace/.claude/agents ]; then
    mkdir -p ./agents
    # Remove stale .md files in mirror (handles deletions)
    find ./agents -maxdepth 1 -type f -name "*.md" -delete
    # Copy current agent .md files
    cp /workspace/.claude/agents/*.md ./agents/ 2>/dev/null || true
fi

# Pre-commit secret scrub: any tracked file may contain API keys from
# pasted workflow JSONs. Replace common patterns in-place before staging.
python3 - <<'PY'
import re, pathlib
patterns = [
    (re.compile(r"xai-[A-Za-z0-9_]{20,}"), "[REDACTED_XAI_KEY]"),
    (re.compile(r"sk-(?:ant-|proj-)?[A-Za-z0-9_-]{30,}"), "[REDACTED_KEY]"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{20,}"), "[REDACTED_GITHUB_PAT]"),
    (re.compile(r"AIza[A-Za-z0-9_-]{30,}"), "[REDACTED_GOOGLE_KEY]"),
]
root = pathlib.Path("/workspace/.claude/skills")
for p in root.rglob("*.json"):
    if ".git" in p.parts: continue
    try: s = p.read_text()
    except Exception: continue
    new = s
    for pat, repl in patterns:
        new = pat.sub(repl, new)
    if new != s:
        p.write_text(new)
        print(f"scrubbed: {p.relative_to(root)}")
PY

git add .
if git diff --cached --quiet; then
    echo "Nothing to commit"
    exit 0
fi
COMMIT_MSG="${1:-Update skills}"
git commit -m "$COMMIT_MSG"
git push origin main
echo "✓ Pushed: $COMMIT_MSG"
