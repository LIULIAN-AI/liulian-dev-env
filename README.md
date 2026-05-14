# liulian-dev-env

> **Language:** English | [中文](README.zh.md) *(pending)*

**One-click LIULIAN dev environment** across Linux / macOS / Windows
WSL / Codespaces / Gitpod / VS Code Remote Containers. Clones the 7-repo
federation, builds a workspace image, starts all sidecar services, maps
every port to your host browser.

LIULIAN is an open-source production stack for **spatio-temporal AI**
forecasting (hydrology, energy, healthcare time-series). This repo
is the *developer surface*. The production deploy surface lives in
[`liulian-ops`](https://github.com/liulian-ai/liulian-ops).

---

## TL;DR

### Codespaces (zero local setup)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/liulian-ai/liulian-dev-env)

Click the badge. Wait ~3 min for the image to build, sibling repos to
clone, and ports to forward. Then in the Codespaces terminal:

```bash
make install     # one-shot: install all repo deps
make api & make web
```

### VS Code Remote Containers (local Docker)

1. Install [VS Code](https://code.visualstudio.com) + the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).
2. Clone this repo and open in VS Code.
3. Cmd+Shift+P → "Dev Containers: Reopen in Container".
4. Same `make install && make api & make web`.

### Gitpod (cloud IDE)

Visit https://gitpod.io/#https://github.com/liulian-ai/liulian-dev-env

### Linux (Ubuntu / Debian / Fedora / Arch)

```bash
curl -fsSL https://raw.githubusercontent.com/liulian-ai/liulian-dev-env/main/scripts/bootstrap-linux.sh | bash
```

### macOS (Intel + Apple Silicon)

```bash
curl -fsSL https://raw.githubusercontent.com/liulian-ai/liulian-dev-env/main/scripts/bootstrap-macos.sh | bash
```

### Windows (PowerShell + WSL2)

```powershell
irm https://raw.githubusercontent.com/liulian-ai/liulian-dev-env/main/scripts/bootstrap-windows.ps1 | iex
```

---

## What it installs / starts

| Layer | What | Where it ends up |
|---|---|---|
| Container runtime | Docker + docker compose v2 | Your machine |
| Workspace image | Ubuntu 24.04 + node 20 + pnpm + python 3.11 + uv + helm + kubectl + terraform + gh | Built locally as `liulian/workspace:dev` |
| Sibling repos | 7× `liulian-*` cloned into `$LIULIAN_WORKSPACE` (default `~/liulian`) | Bound to `/workspace` in the container |
| Services | Postgres · Redis · MinIO | Sidecars on the docker network |
| Optional | Ollama (local LLM) · Prometheus · Grafana | `make dev-full` profile |

## Port map (all forwarded to host `localhost`)

| Port | Service | URL |
|---|---|---|
| 8000 | liulian-api | http://localhost:8000/api/docs |
| 8001 | liulian-agent | http://localhost:8001/health |
| 8002 | liulian-ingest | http://localhost:8002/health |
| 3000 | liulian-web (Next.js) | http://localhost:3000 |
| 8081 | liulian-mobile (Expo) | http://localhost:8081 |
| 6006 | Storybook | http://localhost:6006 |
| 8080 | MkDocs docs | http://localhost:8080 |
| 8888 | static demo HTMLs | http://localhost:8888 |
| 5432 | Postgres | `psql -h localhost -U liulian liulian_api` |
| 6379 | Redis | `redis-cli` |
| 9000 | MinIO S3 API | (programmatic) |
| 9001 | MinIO console | http://localhost:9001 (`minioadmin/minioadmin`) |
| 11434 | Ollama (dev-full only) | http://localhost:11434 |
| 9090 | Prometheus (dev-full only) | http://localhost:9090 |
| 3001 | Grafana (dev-full only) | http://localhost:3001 |

## Common Make targets

```bash
make help          # full menu
make dev           # build image + start core services + workspace
make dev-full      # also start ollama, prometheus, grafana
make install       # install Python + JS deps in every repo (one-shot)
make api           # start liulian-api inside workspace, forwarded to 8000
make agent         # start liulian-agent  on 8001
make web           # start liulian-web    on 3000
make all           # install + api + agent + web + health
make health        # ping all /healthz endpoints
make shell         # drop into the workspace container
make status        # service + port table
make logs          # tail all services
make stop          # stop services, keep volumes
make destroy       # nuclear — also delete volumes (asks confirmation)
make seed          # load SwissRiver demo data
```

## Environment

Copy `.env.example` → `.env`. Optional LLM provider keys:

- `DEEPSEEK_API_KEY` — cheapest production-grade default (DeepSeek V4)
- `GLM_API_KEY` — best for Chinese tasks (Zhipu)
- `GEMINI_API_KEY` — long context + multimodal (Google)
- `ANTHROPIC_API_KEY` — high-quality reasoning
- `LIULIAN_OFFLINE=1` — force local Ollama only (sovereign / offline)

## Architecture

The container does NOT run any LIULIAN service itself by default; it's
a *workspace* with shells, editors, and CLIs. Services start on demand
via `make api` etc. and their files live in the mounted sibling
directories so edits on host = edits in container.

```
   Host
   └── ~/liulian/                        (sibling clones)
       ├── liulian-python/
       ├── liulian-api/
       ├── liulian-agent/
       ├── liulian-ingest/
       ├── liulian-web/
       ├── liulian-ops/
       ├── liulian-design-system/
       └── liulian-dev-env/  ◄ this repo (build context for image)

   Container
   └── /workspace -> bind mount of ~/liulian/    (your edits live here)
```

## When to use this vs `liulian-ops`

| You want to… | Use |
|---|---|
| Spin up the federation on your laptop / Codespaces | **this repo** |
| Run a smoke test of all services locally | **this repo** (`make all`) |
| Deploy to staging or production | [`liulian-ops`](https://github.com/liulian-ai/liulian-ops) |
| Roll out a Helm release across services | `liulian-ops` |
| Write a new reusable CI workflow | `liulian-ops/.github/workflows/` |
| Run the deploy CLI `liulianctl` | `liulian-ops` |

## License

MIT. (Workspace image build leverages patterns from the `liulian-dev-env`
public repo — see `liulian-python/docs/strategy/adr/0006-fork-and-adapt-from-liulian.md`
for attribution.)
