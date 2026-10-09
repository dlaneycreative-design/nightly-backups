#!/usr/bin/env bash
# Nightly 3am backup: LlamaChat, E2, and the Studio.
# Run by the nightly-backup-3am cron job. Safe to run by hand too.
set -euo pipefail
export PATH="$HOME/workspace/bin:$PATH"

DATE=$(TZ=America/Denver date +%F)
STAMP=$(TZ=America/Denver date +"%Y-%m-%d %I:%M %p %Z")
BACKUP_DIR="$HOME/workspace/nightly-backups"
TODAY_DIR="$BACKUP_DIR/$DATE"
TAG="nightly-$DATE"

echo "=== Nightly backup $STAMP ==="

# 1. Studio + E2 (thestudio-real repo): commit, push, tag
echo "--- Studio + E2 ---"
cd "$HOME/workspace/thestudio-real"
git add -A
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "Nightly backup $DATE" --quiet
  echo "committed changes"
else
  echo "no changes to commit"
fi
git push origin master --quiet 2>&1 | tail -1 || echo "push had output (see above)"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "tag $TAG already exists"
else
  git tag "$TAG"
  git push origin "$TAG" --quiet
  echo "tagged $TAG"
fi
STUDIO_SHA=$(git rev-parse --short HEAD)

# 2. LlamaChat: tarball (it's not a git repo)
echo "--- LlamaChat ---"
mkdir -p "$TODAY_DIR"
tar -czf "$TODAY_DIR/llamachat-v2.tar.gz" \
  --exclude=node_modules --exclude=.next --exclude=.git --exclude=.vercel \
  -C "$HOME/workspace" llamachat-v2
LLAMA_SIZE=$(du -h "$TODAY_DIR/llamachat-v2.tar.gz" | cut -f1)
echo "llamachat-v2.tar.gz ($LLAMA_SIZE)"

# 3. Plain-English README for tonight
cat > "$TODAY_DIR/README.md" <<EOF
# Backup for $DATE

Taken at $STAMP.

## What's here

- **llamachat-v2.tar.gz** ($LLAMA_SIZE) — the entire LlamaChat site. Download and unzip to restore.
- **Studio + E2** — not in this folder because they're already in git. Go to the [thestudio-io repo](https://github.com/dlaneycreative-design/thestudio-io), click Tags, open \`$TAG\` (commit \`$STUDIO_SHA\`). That's tonight's exact copy of both sites.

## Restore cheat sheet

| Site | How to restore |
|------|---------------|
| LlamaChat | Unzip llamachat-v2.tar.gz |
| Studio (thestudio.io) | thestudio-io repo, tag \`$TAG\` |
| E2 (e2planet.com) | thestudio-io repo, tag \`$TAG\` (E2 lives in the \`e2/\` folder) |
EOF

# 4. Push the backup repo
echo "--- Pushing backup repo ---"
cd "$BACKUP_DIR"
git add -A
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "Backup $DATE" --quiet
  git push origin master --quiet 2>&1 | tail -1 || true
  echo "backup repo pushed"
else
  echo "nothing new in backup repo"
fi

echo "=== Done $STAMP ==="
