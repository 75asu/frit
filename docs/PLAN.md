# Frit — Project Plan

Frit is a public OSS project that demonstrates AIRE competency by building and operating a local replica of Anthropic's product stack, then applying production-grade reliability engineering on top of it.

---

## The Concept

Can't run 1000 GPUs with follow-the-sun oncall, multi-cloud serving, and weekly ops reviews? Build the PATTERNS at homelab scale. The artifact isn't the infrastructure - it's the postmortems, SLO frameworks, chaos experiment writeups, ops review cadence, and architectural decisions. That's what Anthropic would actually evaluate.

Frit is a single-GPU lab that mimics Anthropic's AIRE operational model: the token path, the observability stack, the oncall philosophy, the ops review cadence, the chaos engineering discipline, and the incident response process. Shrink the scale. Keep the rigor.

---

## Project Decision: Separate From Kiln

**Frit is a standalone project.** Do not merge into Kiln.

- Kiln = sandbox compute platform. Job: run arbitrary workloads in isolated containers.
- Frit = reliability pattern lab. Job: demonstrate AIRE competency through token path simulation, SLOs, chaos engineering.

Merging them creates a "do everything" project that ships never. Two focused repos ship faster and tell a cleaner story. Kiln's README links to Frit as the reliability layer. Frit's README links to Kiln as the infrastructure layer. One narrative, two repos.

### The Kiln ↔ Frit Cross-Reference

Kiln README:
> "For production reliability patterns at GPU scale, see [Frit](https://github.com/binarysquadd/frit) -- our homelab simulation of Anthropic's AIRE operational model, built using container isolation techniques from Kiln."

Frit README:
> "The container isolation primitives used in this lab are built with techniques from [Kiln](https://github.com/binarysquadd/kiln) -- our sandbox compute platform. Kiln provides the infrastructure layer. Frit proves it can be run reliably at scale."

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       USER LAYER                            │
│  Open WebUI (:3000)        │  Aider / Hermes (CLI)          │
│  claude.ai equivalent      │  claude code equivalent        │
└────────────────────────────┴────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│              LiteLLM Proxy (:4000)                          │
│  Claude API equivalent                                      │
│  rate limiting · model routing · per-backend metrics        │
└──────────────────────────┬──────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
  ┌────────▼──────┐ ┌──────▼──────┐ ┌─────▼────────────────┐
  │ vLLM GPU      │ │ vLLM CPU    │ │ Observability Stack   │
  │ (:8000)       │ │ (:8001)     │ │ DCGM → Prometheus     │
  │ primary       │ │ TPU sim     │ │ Grafana · Loki        │
  │ Qwen2.5-7B    │ │ high lat.   │ │ Alertmanager          │
  └────────┬──────┘ └─────────────┘ └──────────────────────┘
           │
  ┌────────▼──────┐
  │ Tesla T4      │
  │ 16GB VRAM     │
  │ CUDA 13.0     │
  │ Driver 580    │
  └───────────────┘
```

Each hop produces metrics. Each layer can fail independently. The system mirrors Anthropic's "every hop from SDK through network, API layers, serving infrastructure, and accelerators and back" -- just with 1 GPU instead of 1000.

---

## What It Simulates

| Anthropic Reality | Frit Simulation |
|------------------|---------------------|
| Multi-cloud (AWS + GCP) | Single host, LiteLLM "platform" label in metrics simulates cloud routing |
| Multi-accelerator (GPU + TPU + Trainium) | Real NVIDIA GPU (vLLM :8000) + CPU-only vLLM (:8001, simulated TPU) |
| 1000+ GPU fleet | 1 GPU with load test traffic scaled to saturate it |
| Follow-the-sun oncall | Simulated shift handoffs with structured handoff docs |
| Weekly ops reviews | Real weekly reviews of Frit SLOs, error budgets, incidents |
| Pager as lens | Real Alertmanager alerts → deliberate incident response → postmortem → roadmap item |
| Token path monitoring | Real Prometheus metrics at each hop with dashboard |
| SLO framework | Real error budgets, burn rate alerts, SLO dashboards |
| Chaos engineering | Deliberate failure injection at each layer, documented |
| Incident postmortems | Blameless postmortems in a public repo for every chaos experiment |

### Anthropic Pattern → Frit Implementation

| Anthropic Pattern | Frit Implementation | Tool | Status |
|------------------|-------------------|------|--------|
| claude.ai web chat | Open WebUI — multi-user, streaming, model switching | Open WebUI | M3 |
| Claude API platform | LiteLLM proxy — rate limiting, routing, usage tracking | LiteLLM | M3 |
| Claude Code CLI | Aider / Hermes connected to LiteLLM | Aider / Hermes | M3 |
| Multi-platform serving (API + Bedrock + Vertex AI) | LiteLLM routing to `vllm-gpu`, `vllm-cpu`, `vllm-slow` with `platform` label in metrics | LiteLLM config | M5 |
| Multi-accelerator (GPU + TPU + Trainium) | vLLM on T4 (GPU) + vLLM CPU-only (simulated TPU) + latency-injected backend (simulated Trainium) | Docker | M5 |
| Sticky routing | LiteLLM session affinity — same user routes to same backend | LiteLLM config | M5 |
| Canary deployment | LiteLLM routes 10% traffic to secondary backend, Grafana shows per-backend TTFT divergence | LiteLLM config | M5 |
| Evaluation pipeline | `cmd/eval-runner`: same prompt to all backends, compare output (length, chars, language) | Go | M5 |
| Privacy-controlled logs | Two Loki streams: `ops-log` (metrics only) and `debug-log` (full prompt, access-controlled) | Loki config | M4 |
| Weekly ops reviews | Weekly markdown in `ops-reviews/YYYY-WNN.md` reviewing SLO dashboard and error budget | Docs | M8 |
| Incident postmortems | Blameless postmortems for every chaos experiment in `postmortems/` | Docs | M7 |
| SLO framework | `SLO.md` with error budgets, burn rate policies, Alertmanager rules | Prometheus + Docs | M4 |
| Langfuse tracing | LLM observability — traces every call: tokens, cost, latency, quality | Langfuse (:3030) | M9 |
| Eval gates in CI | Extend eval-runner to output pass/fail. Block deploys if evals degrade. | Go + CI config | M9 |
| Per-agent cost meter | Track cost per agent session (tokens, model, vectors) via Langfuse dashboard | Langfuse + cmd/cost-meter | M9 |
| OTEL traces | Add otel-collector. Go services emit OTEL spans. Langfuse ingests them. | otel-collector (:4317) | M9 |

### New Concepts (May 2026 — from AI Platform JD research)

These four concepts came from a real AI Platform SRE JD (MakroPRO, Bangkok). They're the "above the LLM" layer of AIRE — agent platform observability, eval gates, FinOps. All fit naturally into frit's existing architecture.

| Concept | What it does | Why frit needs it |
|---------|-------------|------------------|
| **Langfuse** | Open-source LLM observability. Traces every LiteLLM call: prompt, tokens used, cost, latency, quality scores. | The concrete tool for "AI-specific observability" Anthropic mentions. Installs alongside Prometheus/Grafana. |
| **Eval gates** | `cmd/eval-runner` already compares GPU vs CPU output. Eval gates extend this to CI: if eval scores drop below threshold, deployment is blocked. | Turns an observability tool into a reliability enforcement mechanism. This is what AIRE does. |
| **Per-agent cost meter** | Token counts, vector query costs, model inference costs — tracked per individual agent/session. Langfuse provides native cost dashboards. | FinOps applied to AI workloads. A Staff-level concern made concrete. |
| **OpenTelemetry traces** | Standard observability protocol. Existing Go services (gpu-exporter, eval-runner, chaos-injector) emit OTEL spans. otel-collector forwards to Langfuse. | Bridges standard observability to AI-native observability. One protocol, all tools. |

---

## What You DON'T Need

This is not an indie hacker SaaS. No payments. No custom frontend. No custom Go API gateway. This is a portfolio project that runs on localhost via Docker Compose.

Open WebUI is the UI — no custom frontend needed. LiteLLM is the API gateway — no custom Go proxy needed. Aider or Hermes connect to LiteLLM as the coding agent — no additional tooling needed. The OSS stack handles everything. Your job is to make it reliable, not to reinvent it.

You also don't need a cutting-edge model. You need a REALISTIC TOKEN PATH. Qwen2.5-7B or Llama3.1-8B fit in the T4's 16GB VRAM and produce coherent output. The reliability patterns are identical whether the model is 7B or 700B — the GPU bottleneck, the TTFT degradation under load, the OOM behavior under concurrent requests are all the same.

---

## Product Stack

| Layer | Tool | Port | Role |
|-------|------|------|------|
| Chat UI | **Open WebUI** | `:3000` | claude.ai equivalent — multi-user, streaming, model switching |
| API proxy | **LiteLLM** | `:4000` | Claude API equivalent — routing, rate limiting, multi-backend |
| Inference (GPU) | **vLLM** | `:8000` | Claude model equivalent — high-throughput GPU inference |
| Inference (CPU) | **vLLM CPU** | `:8001` | Simulated degraded backend — higher latency, used in M5 |
| Coding agent | **Aider** or **Hermes** | CLI | Claude Code equivalent — connects to LiteLLM |

**Model choice for T4 (16GB VRAM):**
- `Qwen/Qwen2.5-7B-Instruct` — fits in 6GB, strong instruction following, leaves 10GB headroom for concurrent requests
- `meta-llama/Llama-3.1-8B-Instruct` — fits in 8GB, strong coding performance for Aider sessions
- Start with Qwen2.5-7B. Swap to Llama3.1-8B if coding agent quality matters more.

### The Full Frit Stack (All Free, All OSS)

```
docker-compose.yml:
  open-webui:         # claude.ai equivalent — chat UI, streaming, multi-user (:3000)
  litellm:            # Claude API equivalent — proxy, rate limiting, routing (:4000)
  vllm:               # Claude model equivalent — GPU inference, Qwen2.5-7B (:8000)
  vllm-cpu:           # CPU-only backend — simulated degraded backend (:8001)
  dcgm-exporter:      # GPU metrics (utilization, VRAM, temp, power) → Prometheus (:9400)
  prometheus:         # metrics collection — GPU + vLLM + LiteLLM (:9090)
  grafana:            # dashboards — TTFT, throughput, GPU health, SLO burn rate (:3001)
  loki:               # structured log aggregation (:3100)
  alertmanager:       # SLO burn rate alerts (:9093)
  langfuse:           # LLM observability — traces, cost, quality scores (:3030)
  otel-collector:     # OpenTelemetry collector — ingests spans, forwards to Langfuse (:4317)
  chaos-injector:     # Go CLI, injects failures (GPU OOM, network partition, bad model)

# CLI tools — run on host, connect to LiteLLM:
# aider --openai-api-base http://localhost:4000   (claude code equivalent)
# hermes chat (already built in agent-box, points to LiteLLM)
```

---

## Project Structure

```
github.com/binarysquadd/frit/
├── README.md                         # "Anthropic product stack replica + AIRE reliability practice"
├── ARCHITECTURE.md                   # Full architecture with ASCII diagrams
├── SLO.md                            # Error budget policies, SLIs, burn rate alerts
├── deploy/
│   ├── docker-compose.yaml           # Boots entire stack (Open WebUI + LiteLLM + vLLM + observability)
│   ├── litellm/
│   │   └── litellm-config.yaml       # Model backends, routing strategy, rate limits
│   ├── prometheus/
│   │   ├── prometheus.yml            # Scrape: dcgm-exporter, vLLM, LiteLLM
│   │   └── rules.yaml                # SLO recording rules, burn rate alerts
│   ├── grafana/
│   │   └── dashboards/
│   │       └── token-path.json       # Open WebUI → LiteLLM → vLLM → GPU, TTFT + GPU health
│   └── loki/
│       └── loki-config.yaml          # ops-log + debug-log streams
├── cmd/
│   ├── gpu-exporter/main.go          # M1: NVML → Prometheus (~300 lines Go)
│   ├── eval-runner/main.go           # M5: same prompt to all backends, compare output
│   ├── chaos-injector/main.go        # M7: chaos CLI (gpu-oom, network-partition, bad-model)
│   └── load-tester/main.go           # M6: ramp, soak, spike test patterns
├── ops-reviews/
│   ├── 2026-W22.md                   # Weekly: SLO dashboard, error budget, incidents, action items
│   └── template.md
├── postmortems/
│   ├── 2026-06-03-gpu-oom.md         # Blameless postmortem: what, when, impact, root cause, actions
│   └── template.md                   # Includes leadership communication section
├── chaos-experiments/
│   ├── 001-gpu-memory-exhaustion.md  # Hypothesis → Method → Observation → Conclusion
│   └── template.md
├── docs/
│   ├── cost-model.md                 # TCO at 1000-GPU scale: compute, network, staffing
│   ├── adr/
│   │   ├── 001-vllm-vs-llama-cpp.md
│   │   ├── 002-litellm-vs-custom-gateway.md
│   │   └── template.md
│   └── sre-charter.md                # Reliability philosophy, oncall expectations, severity definitions
├── session-log.md                    # Raw session notes — feeds blog posts
└── Makefile
    # make up       → docker compose up (full stack)
    # make chat     → open localhost:3000 in browser
    # make metrics  → open Grafana
    # make chaos    → run chaos-injector
    # make review   → open this week's ops review
```

---

## Implementation Order (Build This Weekend)

1. **Hour 1:** `docker compose up` — vLLM (GPU) + LiteLLM + Open WebUI. Send one prompt through the full stack. Milestone: real token path.
2. **Hour 2-3:** Write `cmd/gpu-exporter/main.go`. NVML → Prometheus metrics. Wire into docker-compose. Grafana dashboard shows GPU util, VRAM, TTFT.
3. **Hour 4-5:** Write `cmd/load-tester/main.go`. Sends concurrent prompts through LiteLLM, measures TTFT. Define SLOs in `SLO.md`.
4. **Day 2:** First chaos experiment. GPU OOM injection. Document hypothesis, method, observation, conclusion. First postmortem.
5. **Day 3:** LiteLLM fallback routing to vllm-cpu. Write `cmd/eval-runner/main.go` to compare GPU vs CPU responses. Equivalence SLO.
6. **Day 4:** Alertmanager burn rate alerts. First ops review. Push everything public.

By end of weekend, Frit has a real inference stack, a TTFT dashboard, one chaos experiment, one postmortem, and burn rate alerts. Public on GitHub.

---

## Implementation Phases (Extended)

### Phase 1: The Token Path (Weekend 1)

- `docker compose up` - Open WebUI + LiteLLM + vLLM (GPU) + vLLM (CPU) + observability
- `cmd/gpu-exporter/main.go` - NVML → Prometheus (custom TTFT and GPU util metrics)
- `cmd/load-tester/main.go` - sends concurrent prompts through LiteLLM, measures TTFT
- Grafana dashboard showing the full token path: WebUI/Aider → LiteLLM → vLLM → T4

### Phase 2: Observability + SLOs (Weekend 2)

- Define SLOs for the Frit service
- Prometheus recording rules for SLI calculation
- Error budget burn rate alerts in Alertmanager
- Grafana SLO dashboard with remaining error budget
- Structured logging at each hop → Loki

### Phase 3: Load Testing (Weekend 3)

- k6 load test scripts with varying traffic patterns
- Ramp test: find the breaking point of the single GPU
- Soak test: run at 70% capacity for 4 hours, observe degradation
- Spike test: sudden 5x traffic burst
- Document: how does the token path behave under each pattern?

### Phase 4: Chaos Injection (Weekend 4)

Pre-programmed failure modes, triggered via API or CLI:

```
frit chaos inject --type gpu-oom
frit chaos inject --type network-partition --target vllm-gpu
frit chaos inject --type slow-gpu --delay-ms 500
frit chaos inject --type bad-model --model corrupted-weights
frit chaos inject --type litellm-timeout --timeout-ms 50
frit chaos recover --all
```

Each injection produces: alert → incident response → postmortem → SLO impact analysis.

### Phase 5: The Cadence (Ongoing)

- **Monday:** Review last week's SLO dashboard. Did we burn error budget?
- **Wednesday:** Chaos experiment. Inject a failure. Respond. Write it up.
- **Friday:** Postmortem review. What did we learn? What tool would prevent this?
- **Monthly:** Architecture review. What's the weakest link? What should we rebuild?

---

## Why This Works

A candidate who walks an Anthropic interviewer through:

1. "Here's my token path simulator -- SDK to GPU, metrics at every hop"
2. "Here are my SLOs -- 99.9% availability, p99 < 200ms, here's my error budget"
3. "Here are 10 chaos experiments I ran, with postmortems"
4. "Here are my weekly ops review notes going back 3 months"
5. "Here's a PR I merged to the NVIDIA DCGM exporter after discovering a metrics gap during a chaos experiment"

...has demonstrated AIRE competency more concretely than someone who "ran 1000 GPUs at AWS" but never wrote a postmortem or defined an SLO.

Scale is a multiplier of experience, not a substitute for it. Frit proves you have the experience. The scale will come.

---

## Naming

The project is named **Frit**.

Frit is powdered glass used in ceramic glazes and in semiconductor chip packaging - GPU dies are literally bonded using glass frit paste. A kiln fires frit. The name creates a deliberate brand family with Kiln and is completely ownable - no existing software company uses it.

---

## Will This Be Worth the Time? (The AI Anxiety Question)

You're racing AI on two fronts:
1. Will AI automate AIRE before you get hired?
2. Will the roles disappear while you're practicing?

**Short answer: No, for structural reasons.**

### What AI Can and Cannot Automate in SRE

The layers AI CAN automate in the next 6-12 months:
- Log parsing and anomaly detection (already happening)
- Runbook execution for known incident patterns
- Alert noise reduction and correlation
- Routine capacity planning forecasts

The layers AI CANNOT automate in the foreseeable future:
- Physical hardware debugging (GPU ECC errors, thermal throttle cascades, PCIe retraining)
- Novel failure modes that haven't been seen before (by definition, AI can't pattern-match what hasn't happened)
- Incident command where judgment calls have $1M+ consequences and require human accountability
- Cross-team influence and organizational reliability culture
- Real-time physical intuition about GPU fleet health that experienced SREs develop

AIRE specifically is about the layers AI can't automate. It's the hard problems: multi-accelerator fleet management, novel inference failure modes, reliability engineering for systems that are themselves AI.

### Will the Roles Still Exist in 6-12 Months?

Yes. Here's the structural reason: the number of GPUs being deployed is growing exponentially. The number of qualified GPU infrastructure engineers is growing linearly. This supply-demand imbalance exists independently of AI automation.

Every frontier lab and GPU cloud provider needs people who understand GPU reliability. The number of GPUs being deployed is growing exponentially. The number of qualified people is growing linearly. The math favors the candidate.

**Even if Anthropic isn't hiring the month you finish:** CoreWeave is. Or Lambda. Or Nebius. Or a new startup that just raised $500M and desperately needs GPU reliability engineers. The portfolio doesn't expire.

### The Time Investment: Honest Math

What Frit adds:

| Phase | Time | Output |
|-------|------|--------|
| Initial build (Weekend 1) | 10-12 hours | Running vLLM + LiteLLM + Open WebUI stack with TTFT dashboard |
| Weekly practice | 2-4 hours/week | Chaos experiments, postmortems, ops reviews |
| OSS contributions | 1-2 hours/week | PRs to NVIDIA device plugin, DCGM exporter |
| **Total (6 months)** | **~75 hours** | Full AIRE portfolio |

After 6 months, 75 hours of deliberate practice produces:

```
Token path simulator (public repo)
10 chaos experiment writeups
6 postmortems with leadership comms
24 weekly ops review notes
2-3 merged OSS PRs in GPU infrastructure projects
1 SLO framework document
5-10 architecture decision records
1 cost model at 1000-GPU scale
```

**Downside risk:** 75 hours spent building skills that transfer to ANY SRE role. Chaos engineering, SLO frameworks, postmortem culture, GPU observability, OSS contributions -- every one of these makes you a better SRE even if AIRE never works out. No hours are wasted.

**Upside return (realistic sequence):**
- 6 months: qualified for Senior GPU SRE at CoreWeave, Lambda, together.ai ($180K-$280K)
- Year 2-3: Staff GPU SRE at an intermediate company after real fleet experience
- Year 3-4: Anthropic AIRE London (£325K-£390K) -- this is the destination, not the 6-month outcome

The 6-month portfolio does NOT get you to Anthropic. It gets you to the intermediate role that gets you to Anthropic. The doc's own gap analysis says 3-4 years and that remains correct. The intermediate step is not optional.

**ROI math:** 75 hours → unlocks the intermediate GPU SRE market ($180K-$280K range) within 12-18 months, then the path to AIRE compounds from there.

### The Only Way This Fails

If you build privately and never publish. The artifacts must be public. The GitHub repo must be findable. The postmortems must be readable by anyone.

Build Frit. Ship it publicly. Let the portfolio compound. The repo sits there working for you whether Anthropic is hiring this month or next year. Code doesn't expire.

---

## Scout Mission: Testing This Direction

Don't pivot. Scout. This is a low-cost, reversible experiment to test whether GPU infrastructure work excites you enough to justify deeper investment.

### Phase 0: Exploration (6-8 weeks, part-time)

**Week 1-2: Hardware setup**
- Acquire a used GPU machine (Rs 20K-40K budget, OLX/local market)
- Any CUDA-capable GPU works -- GTX 1060 minimum, RTX 2060 ideal
- Install Ubuntu, NVIDIA drivers, CUDA toolkit
- Run nvidia-smi successfully (this is milestone #1)

**Week 3-4: GPU metrics hobby project**
- Build a tiny Go binary: gpu-metrics-exporter
- Queries NVML for GPU memory, temperature, utilization, power
- Exposes as Prometheus metrics endpoint
- Runs in a container with --gpus all passthrough
- ~300 lines of Go, Dockerfile, README
- Push to public GitHub
- Blog post: "How I built a GPU metrics exporter in Go"

**Week 5-6: Deeper infra exploration**
- Install DCGM and explore its metrics surface
- Set up Prometheus + Grafana dashboard for GPU metrics
- Configure nvidia-container-toolkit properly
- Run a PyTorch container on your GPU, observe metrics in Grafana

**Week 7-8: Assessment**
- Review: did this direction excite you, or was it just novelty?
- If excited: Kiln Phase 3 becomes the bridge
- If not: you still learned GPU infra basics and have a hobby project -- useful at any cloud company

### Phase 1+: If You Commit (6+ months)

- Contribute to open-source GPU infra projects (NVIDIA device plugin, DCGM exporter, GPU operator)
- Build GPU-aware sandboxing in Kiln (Phase 3)
- Write architecture deep-dives: GPU scheduling, NVML, MIG partitioning
- Target GPU infra SRE roles at CoreWeave, Lambda, together.ai, Nebius

### Cost Estimate

| Item | Cost |
|------|------|
| Used GPU machine (GTX 1070/RTX 2060) | Rs 20,000-40,000 |
| Electricity (idle GPU: 15W, under load: 150W, 8hrs/day) | Rs 500-800/month |
| Cloud GPU spot instance for experiments (optional) | Rs 100-300/hr, Rs 500-1000 total |
| **Total 2-month experiment** | **~Rs 25,000-45,000** |

That's a cheap career test. If it works, the upside is $250K-$450K. If it doesn't, you keep the GPU for Kiln development and gained GPU literacy.
