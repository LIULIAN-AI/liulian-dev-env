#!/usr/bin/env bash
# LIULIAN one-shot bootstrap — Linux (Ubuntu/Debian/Fedora/Arch).
# Idempotent: re-running is safe.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/liulian-ai/liulian-dev-env/main/scripts/bootstrap-linux.sh | bash
#   OR (from a clone):
#   cd liulian-dev-env && bash scripts/bootstrap-linux.sh

set -euo pipefail

GREEN='\033[32m'
RED='\033[31m'
DIM='\033[2m'
NC='\033[0m'

log() { printf "${GREEN}→${NC} %s\n" "$*"; }
die() { printf "${RED}✗${NC} %s\n" "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "This script is for Linux. macOS: use bootstrap-macos.sh; Windows: bootstrap-windows.ps1"

# 1. Detect package manager
if command -v apt >/dev/null; then PM=apt
elif command -v dnf >/dev/null; then PM=dnf
elif command -v pacman >/dev/null; then PM=pacman
else die "Unsupported distro. apt / dnf / pacman not found."
fi
log "Detected package manager: $PM"

# 2. Docker
if ! command -v docker >/dev/null; then
  log "Installing Docker via get.docker.com…"
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  sudo usermod -aG docker "$USER"
  log "Docker installed. ${DIM}You may need to log out + back in for the docker group to take effect.${NC}"
else
  log "Docker already installed: $(docker --version)"
fi

# 3. docker compose plugin
if ! docker compose version >/dev/null 2>&1; then
  log "Installing docker-compose-plugin…"
  case "$PM" in
    apt) sudo apt update && sudo apt install -y docker-compose-plugin ;;
    dnf) sudo dnf install -y docker-compose-plugin ;;
    pacman) sudo pacman -S --noconfirm docker-compose ;;
  esac
else
  log "Docker compose already present: $(docker compose version --short)"
fi

# 4. git + make + curl (usually already present, but check)
for tool in git make curl; do
  if ! command -v "$tool" >/dev/null; then
    log "Installing $tool…"
    case "$PM" in
      apt) sudo apt install -y "$tool" ;;
      dnf) sudo dnf install -y "$tool" ;;
      pacman) sudo pacman -S --noconfirm "$tool" ;;
    esac
  fi
done

# 5. Clone or update sibling repos
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

# 6. Done — direct user to next step
cat <<EOF

${GREEN}✓ LIULIAN bootstrap complete.${NC}

Next steps:
  cd $WORKSPACE_DIR/liulian-dev-env
  cp .env.example .env       # add DEEPSEEK_API_KEY etc. (optional)
  make dev                   # build workspace image + start services
  make install               # install all repo deps inside workspace
  make api & make web        # start API (:8000) and web (:3000)

Open in browser:
  http://localhost:8000/api/docs    ← Swagger
  http://localhost:3000             ← Next.js dev
  http://localhost:9001             ← MinIO console (admin/minioadmin)

EOF
