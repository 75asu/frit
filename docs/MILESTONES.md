# Frit — Milestone Map

> This is the one section to check when deciding what to work on next. Everything else in the docs folder is context and rationale. When in doubt about what to build next, come here.

---

## What This Project Is

A public OSS project that demonstrates AIRE competency by building and operating a local replica of Anthropic's product stack, then applying production-grade reliability engineering on top of it.

**The product stack (what runs):**

| Anthropic Product | Frit Equivalent | Tool |
|-------------------|----------------|------|
| Claude.ai (web chat) | Local chat UI | **Open WebUI** |
| Claude API / Platform | API proxy, routing, rate limiting | **LiteLLM** |
| Claude model | GPU inference engine | **vLLM** + Qwen2.5-7B or Llama3.1-8B |
| Claude Code (CLI) | Terminal coding agent | **Aider** or **Hermes** |
| CPU / secondary backend | Simulated degraded backend | **vLLM CPU-only** |

**The reliability layer (what gets practiced on top):**
GPU observability, inference SLOs, chaos engineering, load testing, postmortems, and the ops cadence that Staff-level SREs run. Built on a single Lightning.ai Tesla T4, using all free OSS tools. Every milestone ships a real artifact and a blog post.

Repo: `github.com/binarysquadd/frit`
Related: [Kiln](https://github.com/binarysquadd/kiln) — the isolation platform this reliability layer will eventually run on top of.

---

## The Four-Session Execution Plan

**Session 2 (next Lightning.ai open — completes M0):**
- Install DCGM, run `dcgm-exporter`, confirm GPU metrics in Prometheus
- Note exact install steps in session-log.md
- M0 is done when `curl localhost:9400/metrics` returns live GPU metrics

**Session 3 (M1 + M3 start):**
- Write Go NVML exporter (M1): ~300 lines, queries NVML directly, exposes `:9401/metrics`
- Start vLLM with Qwen2.5-7B-Instruct on the T4
- Start LiteLLM routing to vLLM
- Start Open WebUI pointing to LiteLLM
- Open browser at `localhost:3000`, send a chat message, watch GPU spike in Grafana
- Milestone: the "Claude.ai equivalent" is running on the T4

**Session 4 (M3 complete + M4 start):**
- Connect Aider to LiteLLM: `aider --openai-api-base http://localhost:4000`
- Full product stack now running: Open WebUI + Aider → LiteLLM → vLLM → T4
- Design the SLO: TTFT p99 < 500ms over 30min rolling window
- Write Prometheus recording rule and burn rate alert in Alertmanager

**Session 5 (M4 complete + first chaos):**
- Open 5 simultaneous Open WebUI chat sessions, observe TTFT p99 climb
- First chaos experiment: start a VRAM-hungry process alongside vLLM, watch Open WebUI degrade
- Alertmanager fires burn rate alert before manual detection
- Write first blameless postmortem

**Output after session 5:**
- Full product stack: Open WebUI + LiteLLM + vLLM on T4 (M3)
- DCGM + custom NVML exporter + Prometheus + Grafana (M0, M1, M2)
- One production-quality SLO with recording rules and burn rate alerts (M4)
- One chaos experiment and postmortem (M7 start)
- Article 1 draft: "running a local claude.ai equivalent on a t4: the dcgm setup nobody documents"

---

## Milestone Overview

| # | Name | Status | Primary Artifact | Blog Post |
|---|------|--------|-----------------|-----------|
| M0 | GPU Foundation | IN PROGRESS | Session log, Makefile setup | - |
| M1 | GPU Metrics Exporter | NOT STARTED | Go binary (NVML → Prometheus) | "building a gpu metrics exporter in go" |
| M2 | DCGM + Observability Stack | NOT STARTED | Grafana dashboard, Docker Compose | "dcgm vs nvml: what changes" |
| M3 | Inference Layer + Token Path | NOT STARTED | vLLM + LiteLLM + Open WebUI + TTFT dashboard | "measuring ttft on a t4" |
| M4 | SLOs + Alerting | NOT STARTED | SLO.md, Alertmanager rules, error budget | "designing slos for inference workloads" |
| M5 | Multi-Platform Simulation | NOT STARTED | 3 gateways, canary config, equivalence checker | "how anthropic's routing layer works" |
| M6 | Load Testing | NOT STARTED | k6 scripts, breaking point documented | "load testing an llm serving stack" |
| M7 | Chaos + Postmortems | NOT STARTED | chaos-injector CLI, 5 experiments, 3 postmortems | one article per experiment |
| M8 | Cadence + OSS Contributions | ONGOING (starts M3) | 12 ops reviews, 2 merged OSS PRs | monthly summary post |

---

## M0: GPU Foundation

**Status:** IN PROGRESS — Session 1 complete.

**Goal:** Establish the baseline. Confirm the T4 works, Docker GPU passthrough works, and the machine can be reprovisioned from scratch with one command. This is the foundation every other milestone builds on.

**What gets built:**
- [done] `make setup` — provisions Docker, NVIDIA container toolkit, Go on a fresh Lightning.ai T4
- [done] `make checklist` — verifies: nvidia-smi, Docker GPU passthrough, Go version
- [done] nvidia-smi confirmed: Tesla T4, 16GB VRAM, CUDA 13.0, Driver 580, 40C idle, 34W
- [done] Docker GPU passthrough: `docker run --gpus all nvidia/cuda nvidia-smi` shows T4
- [next] DCGM installed, `dcgmi discovery` confirms T4
- [next] `dcgm-exporter` running, `curl :9400/metrics` returns GPU metrics

**Done when:** `curl localhost:9400/metrics` returns live GPU metrics from dcgm-exporter on the T4.

**Content:** Session log entry in `session-log.md`. No blog post at this stage — feeds the M1 article.

---

## M1: GPU Metrics Exporter

**Status:** NOT STARTED

**Goal:** Write a Go binary from scratch that queries NVML directly — no DCGM dependency — and exposes GPU metrics as a Prometheus endpoint. This is the first real artifact. It demonstrates you understand the full stack from hardware API to metrics endpoint, not just running someone else's exporter.

**What gets built:**
- `cmd/gpu-exporter/main.go` (~300 lines Go): queries NVML for `gpu_util`, `mem_used`, `mem_total`, `temperature`, `power_draw`
- Prometheus HTTP endpoint at `:9401/metrics`
- Dockerfile with `--gpus all` passthrough
- `Makefile`: `make build`, `make run`, `make metrics`
- `README.md`: what each metric means, why it matters, how to run

**Stack:**
```
Tesla T4 hardware
    ↓
NVIDIA driver (kernel module)
    ↓
NVML C API
    ↓
Go binary (cgo or nvidia-ml-go bindings)
    ↓
Prometheus /metrics endpoint
    ↓
curl / Prometheus scrape
```

**Done when:** `curl localhost:9401/metrics` returns real GPU metrics from a running container on the T4. Metrics match what `nvidia-smi` shows.

**Content:** dev.to article — "building a gpu metrics exporter in go: what the docs don't tell you" — cover: NVML bindings, what each metric actually measures, the T4 quirks (no ECC, 70W max, 40C idle).

---

## M2: DCGM + Observability Stack

**Status:** NOT STARTED

**Goal:** Replace the custom NVML exporter with the industry standard (DCGM), wire it to Prometheus, and build the first Grafana dashboard. This is the stack Anthropic runs at scale. The goal is to understand *why* DCGM exists on top of NVML — what it adds, what it costs, what it catches that NVML misses.

**What gets built:**
- DCGM + `dcgm-exporter` running in Docker
- Prometheus scraping `dcgm-exporter` at `:9400`
- Grafana dashboard: 5 key metrics (gpu_util, mem_used, temperature, power_draw, ecc_errors)
- Docker Compose: `make up` boots the full observability stack (DCGM + Prometheus + Grafana + Alertmanager)
- First alert rule: `gpu_util > 90%` for 5 minutes fires to Alertmanager

**Done when:** Grafana dashboard shows live GPU metrics from the T4. Alertmanager fires the gpu_util alert when `make chaos-load` is running.

**Content:** dev.to article — "dcgm vs nvml: what changes when you move to the industry standard" — cover: what DCGM adds (grouping, health checks, profiling), what it costs (daemon overhead), what you lose if you skip it.

---

## M3: Inference Layer + Token Path

**Status:** NOT STARTED

**Goal:** Run a real LLM and observe it end-to-end. This is the workload AIRE monitors. Without a real inference workload, the observability stack has nothing meaningful to watch. TTFT (Time To First Token) is the primary user-facing signal — get it into Grafana.

**What gets built:**
- vLLM running Qwen2.5-7B-Instruct on the T4 via `--gpus all`, OpenAI-compatible API at `:8000`, Prometheus metrics at `:8001`
- LiteLLM proxy at `:4000` routing to vLLM, with rate limiting and per-request logging
- Open WebUI at `:3000` connected to LiteLLM — the claude.ai equivalent, accessible in browser
- Aider connected to LiteLLM: `aider --openai-api-base http://localhost:4000 --model qwen2.5-7b-instruct`
- Grafana panel: TTFT p50/p95/p99 + GPU memory_used + LiteLLM request rate visible simultaneously

**The token path:**
```
Open WebUI / Aider (CLI) → LiteLLM (:4000) → vLLM (:8000) → T4 GPU
                                  ↓
                    Prometheus metrics (TTFT, throughput, errors)
                                  ↓
                          Grafana dashboard
```

**Done when:** Open a browser at `localhost:3000`, send a chat message, and see TTFT p99 and GPU memory spike on the same Grafana panel in real time.

**Content:** dev.to article — "measuring ttft on a t4: what first-token latency actually tells you" — cover: what TTFT is, why it matters, how it differs from web service p99, what the T4 numbers look like at different concurrency levels.

---

## M4: SLOs + Alerting

**Status:** NOT STARTED

**Goal:** Turn the dashboard into a production-grade reliability system. Define what "good" looks like formally, compute error budgets, and alert on burn rate — not on individual threshold breaches. This is the gap between junior SRE (alert when metric is high) and Staff SRE (alert when error budget is draining at a dangerous rate).

**What gets built:**
- `SLO.md`: TTFT p99 < 500ms on 99.9% of requests over a 30-min rolling window. Error budget policy. Severity tiers.
- Prometheus recording rules (`deploy/prometheus/rules.yaml`): pre-compute the SLI ratio so dashboards are fast
- Burn rate alerts in Alertmanager: two levels — page-now (5x burn rate over 1hr) and ticket (2x burn rate over 6hr)
- Grafana SLO panel: remaining error budget as a percentage gauge, burns red below 10%
- Loki for structured logs: two streams — `ops-log` (metrics only, no prompt text) and `debug-log` (full prompt, requires token)

**Done when:** Let the system run for 10 minutes with `chaos-load` active. Alertmanager fires the burn rate alert before you manually notice TTFT has degraded.

**Content:** dev.to article — "designing slos for inference workloads: what's different from web services" — cover: why TTFT SLOs are different from HTTP SLOs, why burn rate alerts beat threshold alerts, the specific numbers used and why.

---

## M5: Multi-Platform Simulation

**Status:** NOT STARTED

**Goal:** Replicate the architectural pattern from Anthropic's September 2025 postmortem — multi-platform serving, context-window-based routing, canary deployment, equivalence validation. This is what makes the project AIRE-specific rather than generic observability.

**What gets built:**
- LiteLLM configured with 3 model backends: `vllm-gpu` (T4, primary), `vllm-cpu` (CPU-only, simulated TPU), `vllm-slow` (T4 + 200ms injected latency, simulated degraded backend)
- LiteLLM router strategies: `least-busy` and `latency-based` — per-backend metrics visible in Grafana
- Canary config: LiteLLM routes 10% of traffic to `vllm-slow`, Grafana shows per-backend TTFT divergence against primary
- Open WebUI session affinity: same user session consistently routes to same backend (sticky routing pattern from Anthropic postmortem)
- `cmd/eval-runner/main.go`: sends same prompt to all 3 backends, compares output (length, character distribution, language detection — catches the Thai-in-English class of bug Anthropic hit)

**Done when:** Introduce a bad config on the canary backend via LiteLLM. Grafana shows that backend's TTFT diverging from the other two before any manual check.

**Content:** dev.to article — "how anthropic's routing layer works: a homelab reconstruction" — cover: the postmortem patterns, what canary routing looks like in LiteLLM, why equivalence validation matters and how to implement it cheaply.

---

## M6: Load Testing

**Status:** NOT STARTED

**Goal:** Find the breaking point. Document exactly how this inference stack behaves under pressure. This is what you cite in an interview when asked about capacity planning — "at X RPS, TTFT p99 crosses 500ms, GPU hits 90% utilization, and error rate starts climbing."

**What gets built:**
- Load test scripts: ramp (0→max RPS over 10min), soak (70% capacity for 4hrs), spike (5x burst in 30s, hold 2min, recover)
- Either k6 scripts or `cmd/load-tester/main.go` (Go alternative)
- Results documented in `docs/load-test-YYYY-WNN.md`: breaking point RPS, TTFT curve, GPU utilization curve
- SLO budget impact: at max load, how fast does the error budget drain?

**Done when:** You can answer "at what RPS does this system break its TTFT SLO?" with a specific number and the data to back it up.

**Content:** dev.to article — "load testing an llm serving stack: the numbers that actually matter" — cover: why GPU-bound load tests are different from CPU-bound, what TTFT does under load, the specific breaking point found.

---

## M7: Chaos + Postmortems

**Status:** NOT STARTED

**Goal:** Deliberately break the system in reproducible ways and document every failure in blameless postmortem format. This is the AIRE skill that is hardest to fake. Five experiments means five data points that prove you think in failure modes, not just happy paths.

**What gets built:**
- `cmd/chaos-injector/main.go` CLI:
  ```
  chaos inject --type gpu-oom          # fill VRAM with a competing process
  chaos inject --type network-partition --target inference-2  # block traffic to one backend
  chaos inject --type slow-gpu --delay-ms 500    # inject latency into GPU kernel calls
  chaos inject --type bad-model        # serve a corrupted model file
  chaos inject --type sdk-timeout --timeout-ms 50  # force client timeouts
  chaos recover --all
  ```
- Minimum 5 experiments in `chaos-experiments/NNN-name.md`, each with: hypothesis, method, observation, SLO impact, conclusion
- Minimum 3 blameless postmortems in `postmortems/` with: impact statement, timeline, root cause (the 5 whys), action items, what would have detected it faster
- Bar: Alertmanager fires before you manually notice the degradation

**Done when:** 5 experiments documented, 3 postmortems written, and at least 3 of the 5 experiments triggered Alertmanager before manual detection.

**Content:** dev.to article per experiment — "chaos experiment #1: what happens when the gpu runs out of memory mid-inference" — follow the experiment template: hypothesis, what happened, numbers, what the alert showed, lesson.

---

## M8: Cadence + OSS Contributions

**Status:** ONGOING — starts after M3, runs in parallel with M4-M7.

**Goal:** Build the practice that demonstrates Staff-level reliability culture. Not just building, but operating. Weekly ops reviews and OSS contributions are what separates "I built a project" from "I run a reliability practice."

**Weekly rhythm:**
- Monday: open Grafana, review last week's SLO dashboard. Did the error budget burn? Write one paragraph in `ops-reviews/YYYY-WNN.md`.
- Wednesday: chaos experiment OR review an open issue in a GPU OSS project and comment/submit a PR
- Friday: if there was an incident (chaos or real), write the postmortem. Otherwise, update the ops review note.

**Monthly:**
- Architecture review: what's the weakest link in the current stack? Write one `docs/adr/NNN-title.md`.
- Article: "N months of gpu sre practice: what I learned this month."

**OSS targets (in priority order):**
1. `NVIDIA/dcgm-exporter` — the tool being used. Bugs or documentation gaps found during M2 are PRs.
2. `kubernetes/k8s-device-plugin` — GPU scheduling. Good for K8s-adjacent AIRE signal.
3. `kserve/kserve` — inference serving orchestration. Higher complexity, bigger signal.
4. `ray-project/kuberay` — distributed inference with Ray. Stretch target.

**Done when:** 12 weekly ops reviews written (3 months of cadence) + 2 merged OSS PRs in GPU infrastructure projects.

**Content:** Monthly summary post — "N months of gpu sre practice: what I learned operating a homelab llm stack."

---

## Repo Structure (Final State After All Milestones)

```
github.com/binarysquadd/frit/
├── README.md                    — "Anthropic AIRE patterns at homelab scale"
├── ARCHITECTURE.md              — full system design with ASCII diagrams
├── SLO.md                       — SLI definitions, error budgets, burn rate policy
├── Makefile                     — make up, make chaos, make review, make metrics
├── cmd/
│   ├── gpu-exporter/main.go     — M1: NVML → Prometheus (custom exporter)
│   ├── eval-runner/main.go      — M5: equivalence validator across platforms
│   ├── chaos-injector/main.go   — M7: chaos CLI
│   └── load-tester/main.go      — M6: ramp/soak/spike load patterns
├── deploy/
│   ├── docker-compose.yaml      — boots entire stack (Open WebUI + LiteLLM + vLLM + observability)
│   ├── litellm/litellm-config.yaml — routing rules, fallback to vllm-cpu
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules.yaml           — SLO recording rules, burn rate alerts
│   ├── grafana/dashboards/
│   │   └── token-path.json      — SDK → Gateway → LB → Inference → GPU
│   └── loki/loki-config.yaml
├── models/.gitignore            — model weights not committed (pulled by vLLM at startup)
├── ops-reviews/
│   ├── template.md
│   └── YYYY-WNN.md              — weekly ops review notes
├── postmortems/
│   ├── template.md
│   └── YYYY-MM-DD-title.md      — blameless postmortems
├── chaos-experiments/
│   ├── template.md
│   └── NNN-name.md              — hypothesis → method → observation → conclusion
├── docs/
│   ├── adr/                     — architecture decision records
│   ├── load-test-YYYY-WNN.md    — load test results
│   └── cost-model.md            — TCO at 1000-GPU scale
└── session-log.md               — raw session notes (feeds blog posts)
```

---

## Content Map (Article → Milestone)

| Milestone | dev.to Article | When to Write |
|-----------|---------------|---------------|
| M1 | "building a gpu metrics exporter in go: what the docs don't tell you" | When M1 is done |
| M2 | "dcgm vs nvml: what changes when you move to the industry standard" | When M2 is done |
| M3 | "measuring ttft on a t4: what first-token latency actually tells you" | When M3 is done |
| M4 | "designing slos for inference workloads: what's different from web services" | When M4 is done |
| M5 | "how anthropic's routing layer works: a homelab reconstruction" | When M5 is done |
| M6 | "load testing an llm serving stack: the numbers that actually matter" | When M6 is done |
| M7 | "chaos experiment #N: [what broke and what the alert showed]" | After each experiment |
| M8 | "N months of gpu sre practice: what I learned" | Monthly |
