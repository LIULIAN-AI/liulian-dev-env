#!/usr/bin/env bash
# LIULIAN one-shot bootstrap — macOS (Intel + Apple Silicon).
# Requires: Homebrew (will install if missing).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/liulian-ai/liulian-dev-env/main/scripts/bootstrap-macos.sh | bash
#   OR:
#   bash scripts/bootstrap-macos.sh

set -euo pipefail

GREEN='\033[32m'; RED='\033[31m'; DIM='\033[2m'; NC='\033[0m'
log() { printf "${GREEN}→${NC} %s\n" "$*"; }
die() { printf "${RED}✗${NC} %s\n" "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS. Linux: bootstrap-linux.sh; Windows: bootstrap-windows.ps1"

# 1. Homebrew
if ! command -v brew >/dev/null; then
  log "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  log "Homebrew already installed: $(brew --version | head -1)"
fi

# 2. Docker Desktop
if ! command -v docker >/dev/null; then
  log "Installing Docker Desktop via brew…"
  brew install --cask docker
  log "${DIM}Docker Desktop installed. Open it once from /Applications to grant permissions, then re-run this script.${NC}"
  open -a Docker
  echo "Press enter once Docker Desktop is running…"
  read -r
else
  log "Docker already installed: $(docker --version)"
fi

# 3. git / make / curl (BSD versions of make are fine for our Makefile)
for tool in git make curl gh; do
  if ! command -v "$tool" >/dev/null; then
    log "Installing $tool…"
    brew install "$tool"
  fi
done

# 4. Clone or update sibling repos
WORKSPACE_DIR="${LIULIAN_WORKSPACE:-$HOME/liulian}"
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"
log "Workspace: $WORKSPACE_DIR"

for r in liulian-python liulian-api liulian-agent liulian-ingest liulian-web liulian-ops liulian-design-system; do
  if [ -d "$r/.git" ]; then
    log "Updating $r…"
    git -C "$r" fetch --quiet origin || true
  else
    log "Cloning $r…"
    git clone --quiet "https://github.com/liulian-ai/$r.git"
  fi
done

cat <<EOF

${GREEN}✓ LIULIAN bootstrap complete.${NC}

Next:
  cd $WORKSPACE_DIR/liulian-dev-env
  cp .env.example .env
  make dev && make install
  make api & make web

Open:
  http://localhost:8000/api/docs    ← Swagger
  http://localhost:3000             ← Next.js dev
  http://localhost:9001             ← MinIO console

${DIM}Tip on Apple Silicon: Docker may pull amd64 images via emulation. For native arm64 perf,
the workspace Dockerfile is multi-arch and will pick arm64 automatically.${NC}

EOF
