#!/usr/bin/env bash
# Nightly 3am backup: LlamaChat, E2, and the Studio.
# Run by the nightly-backup-3am cron job. Safe to run by hand too.
#
# Rewritten Oct 14 2026 for the studio-live carve. The old script ran
# `git add -A` inside the shared thestudio-real tree, which (a) broke on
# other sessions' staged deletions (Oct 14 3am run) and (b) was secretly
# the publishing glue for orphan files. This version never touches any
# working tree: it tags the studio-live origin head through the GitHub
# API (the proven route from the Oct 14 manual backup) and tarballs
# LlamaChat. The thestudio-io repo remains the frozen archive of the
# full historical sites.
set -euo pipefail
export PATH="$HOME/workspace/bin:$PATH"

DATE=$(TZ=America/Denver date +%F)
STAMP=$(TZ=America/Denver date +"%Y-%m-%d %I:%M %p %Z")
BACKUP_DIR="$HOME/workspace/nightly-backups"
TODAY_DIR="$BACKUP_DIR/$DATE"
TAG="nightly-$DATE"
LIVE_REPO="dlaneycreative-design/studio-live"

echo "=== Nightly backup $STAMP ==="

# 1. Studio + E2 living data (studio-live repo): tag origin head via API
echo "--- Studio + E2 living data (studio-live) ---"
LIVE_SHA=$(gh api "repos/$LIVE_REPO/git/ref/heads/master" --jq '.object.sha')
if gh api "repos/$LIVE_REPO/git/ref/tags/$TAG" >/dev/null 2>&1; then
  echo "tag $TAG already exists on $LIVE_REPO"
else
  gh api "repos/$LIVE_REPO/git/refs" -f ref="refs/tags/$TAG" -f sha="$LIVE_SHA" >/dev/null
  echo "tagged $LIVE_REPO $TAG at $LIVE_SHA"
fi
LIVE_SHA_SHORT=$(echo "$LIVE_SHA" | cut -c1-7)

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
- **Studio + E2 living data** — the queue, the Mike blog source, Living World, and the server-health data live in the [studio-live repo](https://github.com/dlaneycreative-design/studio-live). Tonight's exact copy is the tag \`$TAG\` (commit \`$LIVE_SHA_SHORT\`).
- **Full historical sites** — the complete thestudio.io and E2 trees are archived in the [thestudio-io repo](https://github.com/dlaneycreative-design/thestudio-io). The production sites themselves serve from the slim Cloudflare Pages trees (studio-cutover, e2-carve).

## Restore cheat sheet

| Site | How to restore |
|------|---------------|
| LlamaChat | Unzip llamachat-v2.tar.gz |
| Studio + E2 living data | studio-live repo, tag \`$TAG\` |
| Studio / E2 full history | thestudio-io repo (archive) |
EOF

# 4. Push the backup repo (stage only tonight's folder, by name)
echo "--- Pushing backup repo ---"
cd "$BACKUP_DIR"
git add "$DATE"
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "Backup $DATE" --quiet
  git push origin main --quiet 2>&1 | tail -1 || true
  echo "backup repo pushed"
else
  echo "nothing new in backup repo"
fi

echo "=== Done $STAMP ==="
