# LIULIAN local stack — connected & running (2026-05-19)

The web is now **really connected to a really-running backend**, all on this machine.
Before today the deployed web was a static mock; now the Next.js app fetches live data
from `liulian-api`, and the BI agent panel streams from `liulian-agent`.

## The three tiers

```
  Browser
     │
     ▼
  liulian-web      Next.js 14 dev server      http://localhost:3000
     │  ├─ server-side fetch ─────────────────────────────┐
     │  └─ client-side SSE ──────────────────┐            │
     ▼                                       ▼            ▼
  /forecast page                       liulian-agent   liulian-api
  · ForecastChart (real ECharts)       :8001           :8000
  · KpiStrip  · StationList            BI chat, SSE    REST: /forecasts
  · ChatSidebar ──────────────────────▶ /agent/chat    /models /experiments …
```

- **liulian-api** (`:8000`) — FastAPI. 24 routes across 7 routers
  (health, models, experiments, forecasts, datasets, alerts, reports).
  In-memory data — no database required to run.
- **liulian-agent** (`:8001`) — FastAPI. BI agent, streams Server-Sent Events
  from `POST /agent/chat`. Runs offline in demo mode with scripted SwissRiver
  scenarios (no LLM key needed); add an LLM key for live mode.
- **liulian-web** (`:3000`) — Next.js 14. `/forecast` is the BI canvas.

## Start / stop

```bash
cd "<…>/codes/liulian-python"
bash start-local.sh     # starts all three tiers (idempotent)
bash stop-local.sh      # stops all three
```

Logs: `/tmp/liulian-local/{api,agent,web}.log`.
Cold start takes ~20 s (Next.js first compile).

## How to check each module

### liulian-api (`:8000`)
```bash
curl localhost:8000/healthz
# {"status":"ok","version":"0.1.0","uptime_seconds":…}

curl "localhost:8000/forecasts?station_id=aare-bern" | head -c 300
# real ForecastSeries JSON: timestamps, observed, mean, q05, q95

curl localhost:8000/models | python3 -c "import sys,json;print(len(json.load(sys.stdin)),'models')"
# 23 models
```
Swagger UI: open <http://localhost:8000/api/docs> → "Try it out" on any endpoint.

### liulian-agent (`:8001`)
```bash
curl localhost:8001/health
# {"status":"ok","llm_provider":"GeminiProvider","data_source_mode":"csv"}

curl -N -X POST localhost:8001/agent/chat \
  -H 'Content-Type: application/json' -H 'X-Demo-Mode: 1' \
  -d '{"message":"show the bern forecast"}'
# streams: event: trace … event: chunk … event: suggestions … event: done
```

### liulian-web (`:3000`)
```bash
curl -I localhost:3000/forecast        # HTTP 200
```
The forecast page is server-rendered: if its HTML already contains
`aare-bern` / `patchtst` / `408`, the web→api fetch succeeded.

## How to view the local web

Open a browser on this machine:

| URL | What you see |
|---|---|
| <http://localhost:3000/forecast> | **The connected BI canvas** — station list, a real ECharts Q05–Q95 forecast chart (data from `liulian-api`), KPI strip, and the BI agent panel. Type a question (e.g. *"show the bern forecast"*, *"compare patchtst and chronos"*) and the agent streams a reply from `liulian-agent`. |
| <http://localhost:3000/> | Marketing landing |
| <http://localhost:3000/studio> | Studio (redirects to `/studio/data`) |
| <http://localhost:8000/api/docs> | API Swagger UI |

To prove the connection is real: stop the api (`pkill -f liulian_api`), then
reload `/forecast` (the server fetch is cached ~30 s, so reload once or twice) —
the page falls back to its "liulian-api unreachable" placeholder. Restart the
api and the chart returns.

## What is real vs. still synthetic

- **Real**: the wiring. The Next.js server really HTTP-fetches `liulian-api`;
  the ChatSidebar really opens an SSE stream to `liulian-agent`. Stop a service
  and the web degrades — nothing is faked in the frontend.
- **Synthetic**: `liulian-api` currently *computes* forecast series with a
  deterministic synthesiser (well-shaped Q05–Q95 fans), not yet real model
  inference. The agent answers from scripted SwissRiver scenarios in demo mode.
- **Next depth layer**: wire real Chronos-2 / trained SwissRiver checkpoints
  into `liulian-api`; add an LLM key for live agent mode; deploy to the cloud.

## Fixes made today (integration debt cleared)

- `liulian-agent/agent/loop.py` — imported three deleted neobanker-era tools
  (`bank_matcher`, `db_reader`, `calculator`); rewired the tool registry to the
  six real forecasting tools. The agent could not boot before this.
- `liulian-agent/fixtures/demo_scenarios.json` — was still 100% bank-themed
  (HSBC etc.); rewritten as five SwissRiver forecasting scenarios.
- `liulian-web/.../ChatSidebar.tsx` — called a non-existent agent endpoint
  (`/agents/{persona}/invoke`); fixed to `POST /agent/chat`, added handling for
  the agent's streamed `chunk` events, and minimal markdown rendering.
