# frit

GPU reliability engineering at homelab scale. One Tesla T4. The full inference stack: vLLM, LiteLLM, Open WebUI, DCGM. Real SLOs, chaos experiments, postmortems. One GPU practicing patterns that hold at 1000.

**Status:** M0 in progress — [75asu.github.io/frit](https://75asu.github.io/frit)

---

## What This Is

A public OSS project that demonstrates production-grade GPU reliability engineering on a single Lightning.ai T4. Every milestone ships a real artifact and a blog post.

| Anthropic Stack | Frit Equivalent |
|-----------------|----------------|
| Claude.ai | Open WebUI |
| Claude API | LiteLLM proxy |
| Claude model | vLLM + Qwen2.5-7B on T4 |
| Observability | DCGM + Prometheus + Grafana |

---

## Milestones

| # | Name | Status |
|---|------|--------|
| M0 | GPU Foundation — Tesla T4, DCGM, Docker GPU passthrough | **in progress** |
| M1 | GPU Metrics Exporter — NVML → Prometheus, custom Go binary | queued |
| M2 | DCGM + Observability Stack — Grafana dashboards, Alertmanager rules | queued |
| M3 | Inference Layer + Token Path — vLLM + LiteLLM + Open WebUI, TTFT dashboard | queued |
| M4 | SLOs + Alerting — error budgets, burn rate alerts | queued |
| M5 | Multi-Platform Simulation — canary routing, equivalence validation | queued |
| M6 | Load Testing — ramp/soak/spike, breaking point documented | queued |
| M7 | Chaos + Postmortems — 5 experiments, 3 blameless postmortems | queued |
| M8 | Cadence + OSS Contributions — 12 ops reviews, 2 merged OSS PRs | queued |

---

## Quick Start

### Prerequisites

- [Lightning.ai](https://lightning.ai) account with a T4 studio created
- Python 3.x + `pip install lightning_sdk`

### 1. Clone and configure

```bash
git clone https://github.com/binarysquadd/frit.git && cd frit
make env   # copies .env.example → .env, then fill in your credentials
```

Edit `.env` with your values:

| Variable | Where to find it |
|----------|-----------------|
| `LIGHTNING_API_KEY` | Lightning.ai → profile icon → Keys → API key |
| `LIGHTNING_USER_ID` | Same page, shown next to the API key |
| `STUDIO_TEAMSPACE` | The teamspace name in your Lightning.ai URL |
| `STUDIO_USER` | Your Lightning.ai username |
| `STUDIO_NAME` | Name of your studio (default: `frit`) |

### 2. Download SSH keys (once per machine)

```bash
make keys      # downloads ~/.lightning/lightning_rsa, writes Host frit into ~/.ssh/config
```

Idempotent — safe to re-run. The studio does not need to be running for this step.

### 3. Start the studio and verify

```bash
make start     # boots the T4 (takes ~2-3 min to fully initialize)
make status    # should print: Running
make metrics   # should print live GPU stats from the T4
```

### 4. Provision the studio

```bash
make setup     # installs Go, DCGM, nvidia-container-toolkit via Ansible over SSH
```

If setup fails immediately, the preflight checks will tell you exactly why:
- `No GPU detected` — studio started on CPU, run `make stop && make start`
- `apt is locked` — T4 still initializing, wait 2 min and retry

### Available commands

```bash
make metrics        # live GPU stats (temp, power, VRAM, utilization)
make run CMD="..."  # run any command on the studio remotely
make sync           # push local code changes to the studio
make chaos-memory   # fill GPU VRAM and observe degradation
make chaos-load     # run competing GPU workloads
make clean          # kill all chaos containers
```

---

## Stack

- **GPU** — Tesla T4, 16GB VRAM, CUDA 13.0
- **Inference** — vLLM, LiteLLM, Open WebUI
- **Observability** — DCGM, Prometheus, Grafana, Alertmanager, Loki
- **Custom tooling** — Go NVML exporter, chaos injector CLI, load tester
- **Platform** — Lightning.ai (free tier T4)

---

MIT License — by [@75asu](https://75asu.pages.dev)
