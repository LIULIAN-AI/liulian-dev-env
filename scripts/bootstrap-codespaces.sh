#!/usr/bin/env bash
# Auto-runs inside GitHub Codespaces / VS Code Remote Containers
# AFTER the workspace container is built. Clones sibling repos
# into /workspace so the multi-repo federation is fully set up.

set -euo pipefail

GREEN='\033[32m'; NC='\033[0m'
log() { printf "${GREEN}→${NC} %s\n" "$*"; }

cd /workspace

for r in liulian-python liulian-api liulian-agent liulian-ingest liulian-web liulian-ops liulian-design-system; do
  if [ -d "$r/.git" ]; then
    log "Updating $r…"
    git -C "$r" fetch --quiet origin || true
  else
    log "Cloning $r…"
    git clone --quiet "https://github.com/liulian-ai/$r.git"
  fi
done

log "Federation cloned. Run 'make install' to install all deps, then 'make api' / 'make web'."
