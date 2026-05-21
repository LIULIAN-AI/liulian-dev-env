# UBELIX Cluster — Account Tiers, Billing & Setup (lab/project operating rules)

_Recorded 2026-05-15. Canonical reference for which `#SBATCH` account/partition/
qos to use. **You must always specify the account.**_

## Reference links

| Purpose | URL |
|---|---|
| Partitions & QOS (CPU + GPU, walltimes) | https://hpc-unibe-ch.github.io/runjobs/partitions/ |
| Cost model overview | https://hpc-unibe-ch.github.io/costs/overview/ |
| **Live price list** (needs UniBE intranet / VPN) | https://intern.unibe.ch/dienstleistungen/informatik/dienstleistungen_der_informatikdienste/dienstleistungen___ressourcen/high_performance_computing___hpc___grid/index_ger.html#tab-pane-3 |
| UBELIX status dashboard (node/GPU load) | https://www.ubelix.hpc.unibe.ch/d/a59586dd-c004-4cb7-ab5a-fd27ec7489789/ubelix-status-dashboard?orgId=1&from=now-6h&to=now&var-icpu=icpu-aiub&refresh=5m |

## Billing model (from costs/overview + costs/paygo)

- **GPU jobs:** only **GPU usage is billed**. CPU and memory on a GPU node are
  **not** charged separately. → cost ≈ `GPU_count × wall_hours × GPU_rate`.
- **CPU jobs:** billed on `max(cpu, mem)` — whichever of CPU-share or
  memory-share is larger.
- Public docs do not list CHF rates; the authoritative figure for any job is
  the **`Projected costs this job (CHF)`** line printed by `sbatch` — always
  read and log it.

## Pricing structure (confirmed rates)

Source: the UniBE intranet HPC price page (VPN / intranet-gated —
`intern.unibe.ch/.../index_ger.html#tab-pane-3`), retrieved 2026-05-15.

| Resource | CHF per hour |
|---|---|
| 1 CPU core | 0.002 |
| 1 GPU — RTX 4090 | **0.10** |
| 1 GPU+ — H100 | 0.60 |

- Billing is **per-minute**, usage-based, no long-term commitment (PAYG model).
- **debug / preemptable jobs are free** (confirms tier B = 0 CHF).
- CPU/memory cost uses `max(cpu, mem)`. On GPU nodes only the GPU is billed.
- → A 1× RTX 4090 job costs `0.10 × wall_hours` CHF. A full 12 h job projects
  to 1.20 CHF; actual is lower if it finishes early.
- UBELIX has a resource/cost calculator in progress (not yet available).

### Where the `sbatch` cost block numbers come from

A Paygo submission prints, e.g.:

```
Project/WCKEY                           : inf_prg-research
Cost ceiling (per month)                : 300
Projected costs this job (CHF)          : 1.20
Total project costs for this month (CHF): 17.75
```

These are emitted by UBELIX's Slurm cost plugin **at submission time**:

- **Project/WCKEY** — the billing key (`--wckey`); jobs are billed to it.
- **Cost ceiling (per month)** — the per-month CHF limit configured for that
  wckey by UniBE. For `inf_prg-research` it is **300 CHF/month**.
- **Projected costs this job** — `rate × requested_walltime × resource_count`
  (assumes the job runs its full requested walltime; an upper bound).
- **Total project costs for this month** — sum of all jobs billed to that
  wckey in the **current calendar month**, **across all lab members** sharing
  it (e.g. 17.75 CHF on 2026-05-15, before this effort's jobs). It is a
  *shared, project-level* figure — not this user's personal spend.

> The numbers are obtained simply by reading the `sbatch` stdout; there is no
> separate query command (`sacctmgr show wckey` is permission-denied for
> ordinary users). This project's own 10 CHF cap is tracked independently in
> `ubelix-cost-ledger.md` over only the jobs this effort submits.

## The four tiers

### A — Full free (`gratis`) — DEFAULT for this project

```bash
#SBATCH --account=gratis
#SBATCH --partition=gpu
#SBATCH --qos=job_gratis          # or job_debug for short test jobs
```

- Hard cap: **2× RTX 4090 OR 1× H100** per user.
- QoS run-minute limits: `cpu=11520 CPU·min`, `mem=86400 GB·min` per user.
- sbatch prints: `This job generates no costs!`

### B — Preemptable free (`gratis` on investor nodes)

```bash
#SBATCH --account=gratis
#SBATCH --partition=gpu-invest
#SBATCH --qos=job_gpu_preemptable
```

- Free. Runs on **idle investor GPUs** (3090 / 4090 / A100 / H100 / H200).
- **Can be preempted** (killed) when an investor reclaims the node — design
  jobs to checkpoint + `--resume` (Ray `hpo_resume` already wired).
- sbatch prints: `This job generates no costs!`

### C — Paygo (paid, per actual usage)

```bash
#SBATCH --account=paygo
#SBATCH --wckey=inf_prg-research   # project / billing key
#SBATCH --partition=gpu
#SBATCH --qos=job_gpu
```

- Billed per use; runs **uninterrupted** (not preempted).
- 3090 / 4090 / A100 / H100 / H200; gpu partition max walltime **24 h**.
- sbatch prints a cost block:
  ```
  Project/WCKEY                       : inf_prg-research
  Cost ceiling (per month)            : 300
  Projected costs this job (CHF)      : 14.35
  Total project costs for this month  : 14.35
  ```
- **Project rule:** every Paygo job MUST be logged via
  `jobs/ubelix_cost_tracker.py` — see `ubelix-cost-ledger.md`. Hard self-imposed
  cap **10 CHF total** for this user/effort.

### D — Investment (prepaid) — NOT AVAILABLE YET

```bash
#SBATCH --account=invest
#SBATCH --partition=gpu-invest
#SBATCH --qos=<tbd>
```

- 3× RTX 4090 dedicated. ETA Q1-2026; QoS string TBD. Do not use until the
  lab actually holds an investment.

## How to tell free vs paid

| sbatch output contains | Tier |
|---|---|
| `This job generates no costs!` | A or B (free) |
| `Projected costs this job (CHF) : <n>` | C or D (paid) — **log it** |

## Project usage policy

1. **Default to A (gratis-full).** Use B (preemptable) for extra free capacity
   when gratis QoS minutes are exhausted.
2. **Use C (Paygo) only deliberately** — when a deadline needs uninterrupted,
   immediately-scheduled GPUs. Every Paygo submission is logged; stop at the
   10 CHF cap (see ledger).
3. Concurrency: see memory `cluster_concurrent_sbatch_policy` (currently 2
   concurrent jobs allowed). gratis hard limit is `rtx4090=2`, so 2 concurrent
   jobs ⇒ 1 GPU each.
