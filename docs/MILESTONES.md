# Frit — Milestone Map

> This is the one section to check when deciding what to work on next. Everything else in the docs folder is context and rationale. When in doubt about what to build next, come here.

---

## What This Project Is

A public OSS project that demonstrates AIRE competency by building and operating a local replica of Anthropic's product stack, then applying production-grade reliability engineering on top of it.

**The product stack (what runs):**

| Anthropic Product | Frit Equivalent | Tool | Production basis |
|-------------------|----------------|------|-----------------|
| Claude.ai (web chat) | Local chat UI | **Open WebUI** | - |
| Claude API routing layer | Request routing, prefix-aware dispatch | **vLLM built-in router** | CoreWeave/llm-d pattern |
| Dev API gateway (multi-model testing) | Local proxy for model switching | **LiteLLM** | Dev tool only — not what frontier labs run in prod |
| Claude model | GPU inference engine | **vLLM** + Qwen3-4B-Instruct | CoreWeave's recommended inference engine |
| Claude Code (CLI) | Terminal coding agent | **Aider** | - |
| CPU / secondary backend | Simulated degraded backend | **vLLM CPU-only** | Simulates Anthropic's multi-platform routing |

**The reliability layer (what gets practiced on top):**
GPU observability, inference SLOs, chaos engineering, load testing, postmortems, and the ops cadence that Staff-level SREs run. Built on a single GCP Spot Tesla T4 (the `asu-sandbox` VM), using all free OSS tools. Deployment is GitOps: manifests in `gitops/`, served from an in-cluster Gitea repo, reconciled by Flux. Every milestone ships a real artifact and a blog post.

> **Status note (2026-06-08):** M0 done, M2 core done (DCGM->Prometheus->Grafana dashboard 12239 live), M3 in progress (vLLM Qwen3-4B + Open WebUI + a PodDisruptionBudget on the engine). Moved off Lightning.ai entirely -- the lab runs on the GCP T4 now. Convenience targets added: `make grafana` / `make grafana-pass` / `make prometheus` (open UIs via pure SSH, no local kubeconfig). The four-session plan below is the original Lightning.ai-era sequence, kept for historical context only -- the Milestone Overview table above is the live source of truth.

Repo: `github.com/binarysquadd/frit`
Related: [Kiln](https://github.com/binarysquadd/kiln) — the isolation platform this reliability layer will eventually run on top of.

---

## The Four-Session Execution Plan

**Session 2 (completes M0, historical):**
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
| M0 | GPU Foundation | **DONE** | driver + DCGM + k3s on the GCP T4, one-command reprovision | - |
| M1 | GPU Metrics Exporter | NOT STARTED | Go binary (NVML → Prometheus) | "building a gpu metrics exporter in go" |
| M2 | DCGM + Observability Stack | **DONE (core)** | GPU Operator + kube-prometheus-stack via Flux; DCGM→Prometheus→Grafana dashboard 12239 live. Remaining: gpu_util alert rule + health CronJob | "dcgm vs nvml: what changes" |
| M3 | Inference Layer + Token Path | **IN PROGRESS** | vLLM (Qwen3-4B) + Open WebUI running; PDB added for the engine. Remaining: TTFT p50/p99 Grafana panel | "measuring ttft on a t4" |
| M3.5 | Distributed Tracing (token path) | NOT STARTED | OTEL Collector + Tempo, trace/metric/log correlation | "tracing the llm token path" |
| M4 | SLOs + Alerting | NOT STARTED | SLO.md, Alertmanager rules, error budget | "designing slos for inference workloads" |
| M5 | Multi-Platform Simulation | NOT STARTED | 3 gateways, canary config, equivalence checker | "how anthropic's routing layer works" |
| M5.5 | Eval & Safety Gate | NOT STARTED | eval suite, canary promotion gate | "the eval gate anthropic wished they'd had" |
| M5.6 | Safeguard Model Serving | NOT STARTED | guard model, stricter SLO, fail-safe policy | "serving a safety model" |
| M6 | Load Testing | NOT STARTED | k6 scripts, breaking point documented | "load testing an llm serving stack" |
| M6.5 | HA & Failover (simulated multi-region) | NOT STARTED | active-passive failover, measured RTO | "failover for llm serving" |
| M7 | Chaos + Postmortems | NOT STARTED | chaos-injector CLI, 5+ experiments, 3 postmortems | one article per experiment |
| M8 | Cadence + OSS Contributions | ONGOING (starts M3) | 12 ops reviews, 2 merged OSS PRs | monthly summary post |
| M9 | Multi-GPU Burst (ephemeral) | NOT STARTED | 2× A100 NVLink, tensor-parallel vLLM, NCCL, MIG | "real multi-gpu on a budget" |
| M10 | TPU Burst (ephemeral) | NOT STARTED | JAX/XLA inference on a TPU VM | "a gpu sre's first day on a tpu" |
| M11 | Firmware & Driver Compatibility Ops | NOT STARTED | driver/firmware matrix, staged rollout + rollback | "firmware ops for sres" |
| M12 | Cost & Capacity Model | NOT STARTED | per-token cost meter, fleet TCO model | "what does a million tokens cost" |
| M13 | GPU Fault-Injection + Remediation Operator | NOT STARTED | kubebuilder operator, 2 CRDs: inject synthetic GPU faults, then detect→cordon→drain(PDB-aware)→reset; fleet-scale demo via KWOK + fake-gpu-operator | "building a gpu fault-injection + remediation operator" |

> M3.5 / M5.5 / M5.6 / M6.5 are inserts at their logical position in the existing sequence (decimal-numbered so M0-M8 IDs and the four-session plan stay stable). M9-M12 are advanced extensions; M9-M10 are ephemeral hardware bursts (spin up on Spot, capture one artifact, tear down). All four advanced ones were added from the AIRE gap analysis -- see each section's "Why (AIRE)" note.

---

## M0: GPU Foundation

**Status:** DONE -- driver + DCGM + k3s live on the GCP T4; `make connect` / `make up` reprovision from scratch.

**Goal:** Establish the baseline. Confirm the T4 works, Docker GPU passthrough works, and the machine can be reprovisioned from scratch with one command. This is the foundation every other milestone builds on.

**What gets built:**
- [done] `make setup` — provisions Docker, NVIDIA container toolkit, Go on a fresh GCP T4
- [done] `make checklist` — verifies: nvidia-smi, Docker GPU passthrough, Go version
- [done] nvidia-smi confirmed: Tesla T4, 16GB VRAM, CUDA 13.0, Driver 580, 40C idle, 34W
- [done] Docker GPU passthrough: `docker run --gpus all nvidia/cuda nvidia-smi` shows T4
- [done] DCGM running via the GPU Operator; `nvidia-dcgm-exporter` pod healthy
- [done] dcgm-exporter scraped by Prometheus (ServiceMonitor); GPU metrics confirmed live in Grafana (dashboard 12239)

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

**Status:** DONE (core) -- GPU Operator + kube-prometheus-stack deployed via Flux; DCGM -> Prometheus -> Grafana dashboard 12239 is live with real T4 metrics. Remaining: the `gpu_util > 90%` alert rule + the active health CronJob.

**Goal:** Replace the custom NVML exporter with the industry standard (DCGM), wire it to Prometheus, and build the first Grafana dashboard. This is the stack Anthropic runs at scale. The goal is to understand *why* DCGM exists on top of NVML — what it adds, what it costs, what it catches that NVML misses.

**What gets built:**
- k3s single-node cluster on the T4 (install via Ansible, replaces Docker Compose as the deployment layer)
- NVIDIA GPU Operator via Helm — installs device plugin + DCGM exporter + container toolkit in one shot (OpenAI/CoreWeave pattern)
- kube-prometheus-stack via Helm — Prometheus + Grafana + Alertmanager
- DCGM exporter feeding GPU metrics: gpu_util, mem_used, temperature, power_draw, ecc_errors
- GPU health CronJob — fires every 5 min on a random node, runs CUDA diagnostic, cordons if unhealthy (OpenAI's active health management pattern)
- First alert rule: `gpu_util > 90%` for 5 minutes fires to Alertmanager

**Done when:** Grafana dashboard shows live GPU metrics from the T4. Alertmanager fires the gpu_util alert when `make chaos-load` is running.

**Content:** dev.to article — "dcgm vs nvml: what changes when you move to the industry standard" — cover: what DCGM adds (grouping, health checks, profiling), what it costs (daemon overhead), what you lose if you skip it.

---

## M3: Inference Layer + Token Path

**Status:** IN PROGRESS -- vLLM (Qwen3-4B-Instruct) + Open WebUI running on the T4 via the production-stack chart; a PodDisruptionBudget (minAvailable 1) now protects the engine for the upcoming drain/remediation work. Remaining: the TTFT p50/p95/p99 Grafana panel.

**Goal:** Run a real LLM and observe it end-to-end. This is the workload AIRE monitors. Without a real inference workload, the observability stack has nothing meaningful to watch. TTFT (Time To First Token) is the primary user-facing signal — get it into Grafana.

**What gets built:**
- vLLM deployed as a k8s Deployment via vllm-project/production-stack Helm chart
  - Qwen2.5-7B-Instruct, weights from `/teamspace/studios/this_studio/models/` (persists across restarts)
  - OpenAI-compatible API at `:8000`, Prometheus metrics at `:8001`
  - Routing mode: prefix-aware (KV cache hit rate tracked in Grafana — CoreWeave pattern)
- Open WebUI as a k8s Deployment, exposed via Traefik ingress (built into k3s)
- LiteLLM as optional dev gateway only — for multi-model switching during M5 simulation
- Aider connected directly to vLLM: `aider --openai-api-base http://vllm-svc:8000 --model qwen2.5-7b-instruct`
- Grafana panel: TTFT p50/p95/p99 + GPU memory_used + KV cache hit rate visible simultaneously

**The token path (production-equivalent):**
```
Open WebUI / Aider (CLI)
        │
    Traefik ingress (k3s built-in)
        │
    vLLM k8s Service (:8000)
        │  prefix-aware routing
    vLLM Pod → T4 GPU
        │
    Prometheus metrics (TTFT, TBT, KV cache hit rate, throughput)
        │
    Grafana dashboard
```

**Done when:** Open a browser at `localhost:3000`, send a chat message, and see TTFT p99 and GPU memory spike on the same Grafana panel in real time.

**Content:** dev.to article — "measuring ttft on a t4: what first-token latency actually tells you" — cover: what TTFT is, why it matters, how it differs from web service p99, what the T4 numbers look like at different concurrency levels.

---

## M3.5: Distributed Tracing Across the Token Path

**Status:** NOT STARTED
**Placement:** right after M3 (a token path now exists) and feeds M4. Metrics tell you *something* is slow; traces tell you *where*.

**Goal:** Implement the literal AIRE mandate -- observability across "every hop from the SDK through our network, API layers, serving infrastructure, and accelerators and back." Add distributed tracing so a single slow request can be followed hop by hop and correlated with its metrics and logs.

**What gets built:**
- OpenTelemetry Collector in the k3s cluster
- Instrument the gateway (LiteLLM / Open WebUI ingress) and vLLM to emit OTLP spans; one span per hop: ingress -> router -> vLLM queue -> GPU execution -> response
- Tempo (Grafana stack) as the trace backend
- Grafana correlation: TTFT histogram exemplars link to example traces; click a slow trace -> jump to its Loki logs (the `ops-log` / `debug-log` streams from M4)
- A `token-path` trace view that visually mirrors the M3 ASCII token path

**Done when:** a deliberately slow request in Open WebUI shows a full span waterfall in Tempo, and from the TTFT panel you can pivot panel -> trace -> logs for that exact request ID.

**Content:** dev.to article -- "tracing the llm token path: where the milliseconds actually go."

**Why (AIRE):** JD -- "design and implement monitoring and observability systems across the token path." Metrics + logs (M2-M4) without traces leave the "which hop" question unanswered.

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

## M5.5: Eval & Safety Gate (Regression Detection)

**Status:** NOT STARTED
**Placement:** right after M5 -- promotes the M5 equivalence checker into a continuous, blocking gate.

**Goal:** Build the exact thing Anthropic's September 2025 postmortem says they lacked: *"detection took weeks because [we] lacked sensitive enough evaluations,"* and *"canary deployment didn't catch the issues because evaluations weren't sensitive enough."* Make eval failures block a bad canary automatically.

**What gets built:**
- An eval suite run against every canary backend: benchmark prompts + output-quality checks -- length distribution, language-consistency (catches the "Thai characters in English responses" class of bug), format validity, refusal-rate drift
- Golden-output diffing vs the primary backend (extends `cmd/eval-runner/main.go` from M5)
- A promotion **gate**: a canary is blocked from taking more traffic if eval scores regress beyond a threshold (wired into the M8 cadence / CI)
- Grafana: eval pass-rate per backend over time; alert when a backend's score regresses

**Done when:** re-run the M5 bad-config canary -- the eval gate now flags the quality regression and blocks promotion automatically, instead of you just eyeballing TTFT divergence.

**Content:** dev.to article -- "the eval gate anthropic wished they'd had: catching output corruption before users do."

**Why (AIRE):** the postmortem's central failure was insensitive evals + canary that didn't catch a quality regression. This is the single most AIRE-specific reliability control in the project.

---

## M5.6: Safeguard Model Serving (Safety-Critical Path)

**Status:** NOT STARTED
**Placement:** after M5.5 -- a second, safety-critical serving path with its own SLO.

**Goal:** Serve a guard/moderation model as a separate path with a *stricter* SLO than the model it protects. Straight from the JD: *"Support the reliability of safeguard model serving -- critical for both site reliability and Anthropic's safety commitments."*

**What gets built:**
- A second vLLM serving a small guard model (Llama-Guard-class or a lightweight classifier), behind LiteLLM as a pre/post filter on requests
- A dedicated SLO for the guard path with a higher availability target than the main model, plus an explicit **fail-closed vs fail-open** policy (a safety path must not silently fail open)
- Chaos tie-in: kill the guard model and verify the system enforces the defined fail-safe behavior and pages
- Grafana: guard-path availability + decision latency tracked separately from the main model

**Done when:** requests traverse the guard model; killing it triggers the defined fail-safe behavior and an alert; the guard-path SLO is tracked independently.

**Content:** dev.to article -- "serving a safety model: why the guard path needs a stricter slo than the model it guards."

**Why (AIRE):** safeguard serving is named explicitly in the JD and ties reliability to Anthropic's safety commitments -- a differentiator no generic observability project has.

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

## M6.5: HA & Failover (Simulated Multi-Region)

**Status:** NOT STARTED
**Placement:** after M6 (you now know capacity), before M7 -- failover is a controlled precursor to full chaos.

**Goal:** Simulate the JD line *"assist in design and implementation of high-availability serving infrastructure across multiple regions and cloud providers,"* and reconstruct the blast-radius lesson from the postmortem (sticky routing amplified a misroute across follow-up requests).

**What gets built:**
- Two vLLM backends labelled `region-a` (primary) and `region-b` (standby) -- the "multi-region" stand-in
- LiteLLM health-check-based **automatic failover**: primary dies -> traffic cuts over to standby
- Measure and document **RTO** (time-to-recover) and the count of requests dropped during cutover
- Sticky-session handling: ensure failover does not strand sticky sessions on the dead backend (the exact amplification Anthropic hit on Aug 5-16)

**Done when:** kill the primary mid-load; traffic fails over to standby; you have a measured RTO number and a dropped-request count, and sticky sessions re-home cleanly.

**Content:** dev.to article -- "failover for llm serving: measuring rto when the primary gpu backend dies."

**Why (AIRE):** multi-region HA serving (JD) + the sticky-routing blast-radius failure mode from the September 2025 postmortem.

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
  chaos inject --type misroute --context-pool wrong  # route long-context reqs to the short-context pool
  chaos recover --all
  ```
- The `misroute` experiment reconstructs Anthropic's Aug 5-16 incident: send 1M-context-style requests to a backend configured for short context, then show that **sticky routing amplifies the blast radius** (the same session keeps hitting the wrong pool). Requires the M6.5 two-backend + sticky setup. This is the highest-fidelity reconstruction of a real frontier-lab incident in the project.
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

## M9: Multi-GPU Burst -- Real NVLink + Tensor Parallelism (ephemeral)

**Status:** NOT STARTED -- optional, ephemeral hardware burst.
**Placement:** any time after M3. Spin up, capture one artifact, tear down. Turns "I simulated multi-GPU" into "I ran real tensor parallelism + NVLink NCCL" -- the single biggest "Strong Candidates" gap closed with one afternoon of work.

**What gets built (provision -> capture -> delete):**
- `a2-highgpu-2g` (2x A100 40GB, real NVLink) on Spot, a few hours
- vLLM with `tensor-parallel-size=2` across both GPUs; measure throughput / TTFT vs single-GPU
- `nccl-tests` all-reduce micro-benchmark -- capture bus bandwidth, observe NVLink vs PCIe paths (`nvidia-smi topo -m`)
- **MIG partitioning** demo (A100 supports MIG; the L4 does not) -- split one A100 into instances and schedule them via the k8s device plugin
- Write-up: topology, NCCL bandwidth, tensor-parallel scaling curve -> one ADR + blog, then `gcloud compute instances delete`

**Done when:** tensor-parallel vLLM serves across 2x A100, NCCL bandwidth is captured, MIG instances are scheduled, results are written up, and the instance is deleted.

**Cost / quota:** ~$2-3/hr Spot; a 3-4 hr run ≈ $10-20. A100 quota in the project is likely 0 and needs an increase request first. Confirm Fravity credits cover GPU SKUs.

**Content:** dev.to article -- "real multi-gpu on a budget: nvlink, tensor parallelism, and nccl in an afternoon."

**Why (AIRE):** Full-Scope list -- MIG partitioning, NCCL tuning, topology-aware scheduling, cross-node GPU comms. The L4 single-GPU home cannot show any of these.

---

## M10: TPU Burst -- JAX/XLA, Anthropic's Actual Stack (ephemeral)

**Status:** NOT STARTED -- optional, ephemeral.
**Placement:** any time after M3. Separate hardware from the GPU box.

**Goal:** Touch the accelerator and compiler Anthropic actually runs in production. Their September 2025 incident included an **XLA:TPU miscompilation** -- this burst is the closest you can get to that problem space.

**What gets built (provision -> capture -> delete):**
- A small TPU VM (`v5e-1` or `v5e-8`) on GCP, a few hours
- Run a JAX/XLA inference on a small model; inspect XLA compilation (dump HLO), note AOT-compile vs CUDA mental model
- Document how an XLA miscompilation would manifest as garbled output (the "Thai-in-English" class), and what an SRE signal for it looks like
- GPU-vs-TPU comparison note; delete the TPU VM

**Done when:** a JAX model runs on the TPU VM, you've inspected the XLA HLO, and the GPU-vs-TPU comparison is written; VM deleted.

**Cost / quota:** ~$1-10/hr depending on size; TPU quota is separate and likely needs a request.

**Content:** dev.to article -- "a gpu sre's first day on a tpu: xla, jax, and why anthropic's compiler bug happened."

**Why (AIRE):** multi-accelerator (TPU) from the "Strong Candidates" list; Anthropic explicitly serves on TPUs via XLA, and the postmortem's root cause lived here.

---

## M11: Firmware & Driver Compatibility Ops

**Status:** NOT STARTED -- buildable on the single L4 VM.
**Placement:** after M2 (GPU operator exists). Operational firmware discipline, **not** firmware development.

**Goal:** Own firmware/driver reliability the way an SRE does -- versions, compatibility matrices, staged rollouts -- the OpenAI Frontier Systems "firmware management (operations)" domain, adjacent to AIRE.

**What gets built:**
- Track VBIOS + driver versions (`nvidia-smi -q`) as Prometheus labels; a small inventory table spanning this node (and any M9 burst nodes)
- A driver/firmware **compatibility matrix** doc sourced from NVIDIA release notes (e.g. "driver X + GPU firmware Y = known ECC spike under FP8")
- Simulate a **staged driver rollout** on the node: cordon -> drain -> upgrade driver via the GPU Operator -> DCGM health diag -> uncordon, with a documented rollback path
- ADR: how a firmware bug manifests as an SRE incident (GPU hang, PCIe error, silent corruption) and the detection signal

**Done when:** driver/VBIOS version is a tracked metric, a staged driver upgrade + rollback is documented, and the compatibility-matrix doc exists.

**Content:** dev.to article -- "firmware ops for sres: tracking driver/firmware compatibility without a soldering iron."

**Why (AIRE):** OpenAI Frontier JD "firmware management"; AIRE.md flags this as adjacent literacy worth being able to talk to in an interview.

---

## M12: Cost & Capacity Model (FinOps for Inference)

**Status:** NOT STARTED -- Layer 5.
**Placement:** after M4 (you have SLOs) and M6 (you have throughput numbers). Fills `docs/cost-model.md`, already referenced in the repo structure.

**Goal:** Make inference cost a first-class, observable signal, and extrapolate the homelab numbers to fleet economics -- the "cost-efficient" half of the AIRE Full-Scope mandate.

**What gets built:**
- Per-request/token cost meter: LiteLLM token counts x GPU $/hr / measured throughput -> live `$ / 1M tokens`, exported to Prometheus and shown in Grafana
- `docs/cost-model.md`: extrapolate measured L4 (and M9 A100) throughput + $/hr to TCO at 100 and 1000 GPUs; compare on-demand vs Spot vs committed-use
- The metric that matters to a platform team: **cost per SLO-compliant million tokens** (ties M4 SLO to spend)

**Done when:** Grafana shows live `$/1M tokens` for the running stack, and `cost-model.md` projects fleet-scale TCO with assumptions stated.

**Content:** dev.to article -- "what does a million claude-equivalent tokens cost? a homelab-to-fleet tco model."

**Why (AIRE):** Layer 5 cost meters; Full Scope -- "ensure GPU workloads are reliable, schedulable, and cost-efficient."

---

## M13: GPU Fault-Injection + Remediation Operator

**Status:** NOT STARTED -- the flagship build. Evolves M7's chaos-injector CLI into a real Kubernetes operator.

**Goal:** Close a gap the GPU-on-Kubernetes ecosystem hasn't: there is no "Chaos Mesh for GPUs." NVIDIA's NVSentinel now *remediates* GPU faults, but nothing lets you *test* a remediation pipeline by injecting faults on demand. This operator does both halves -- inject a synthetic GPU fault, then detect it and drive recovery -- so you can prove a cluster actually recovers instead of hoping it does.

**What gets built:**
- A kubebuilder / controller-runtime operator (Go) with two CRDs:
  - `GPUFaultInjection` -- synthesises a fault on a target node: an XID error (e.g. 79, "GPU fallen off the bus"), an ECC error, or a thermal throttle, via `dcgmi --inject` / injected NVML/DCGM signals.
  - `GPUNodeRemediationPolicy` -- the control loop: reads DCGM/NVML, classifies the fault, sets a Node condition, cordons the node, drains pods **respecting PodDisruptionBudgets**, triggers a (mock) GPU reset, and records detection-to-drain latency.
- A per-node DaemonSet detector + a central controller. Blast-radius / topology-aware drain (don't drain two nodes in one NVLink domain at once).
- Prometheus metrics + a Grafana panel for detection-to-drain latency.

**Demoable on one GPU** -- because you *simulate* the fault, no hardware has to actually fail. **Fleet scale** is shown with KWOK + fake-gpu-operator: inject across ~100 fake GPU nodes and watch coordinated remediation.

**Done when:** `kubectl apply` a `GPUFaultInjection` for a synthetic XID -> the controller classifies it, cordons the node, drains the vLLM engine while respecting its PDB, triggers a mock reset, and the detection-to-drain latency appears on the Grafana panel.

**Content:** dev.to article -- "building a gpu fault-injection + remediation operator: testing whether your cluster actually recovers."

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
│   ├── k8s/                     — k8s manifests and Helm values (primary deployment method)
│   │   ├── vllm-values.yaml     — Helm values for vllm-project/production-stack
│   │   ├── kube-prom-values.yaml — Helm values for kube-prometheus-stack
│   │   ├── open-webui.yaml      — Deployment + Service + Ingress
│   │   └── gpu-health-cronjob.yaml — active GPU health check (OpenAI pattern)
│   ├── helmfile.yaml            — single `helmfile apply` to boot entire stack
│   ├── litellm/litellm-config.yaml — multi-model routing config (M5 simulation only)
│   ├── prometheus/rules.yaml    — SLO recording rules, burn rate alerts
│   ├── grafana/dashboards/
│   │   └── token-path.json      — SDK → Traefik → vLLM → GPU + KV cache hit rate
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
| M3.5 | "tracing the llm token path: where the milliseconds actually go" | When M3.5 is done |
| M4 | "designing slos for inference workloads: what's different from web services" | When M4 is done |
| M5 | "how anthropic's routing layer works: a homelab reconstruction" | When M5 is done |
| M5.5 | "the eval gate anthropic wished they'd had: catching output corruption before users do" | When M5.5 is done |
| M5.6 | "serving a safety model: why the guard path needs a stricter slo" | When M5.6 is done |
| M6 | "load testing an llm serving stack: the numbers that actually matter" | When M6 is done |
| M6.5 | "failover for llm serving: measuring rto when the primary gpu backend dies" | When M6.5 is done |
| M7 | "chaos experiment #N: [what broke and what the alert showed]" | After each experiment |
| M8 | "N months of gpu sre practice: what I learned" | Monthly |
| M9 | "real multi-gpu on a budget: nvlink, tensor parallelism, and nccl in an afternoon" | After the burst |
| M10 | "a gpu sre's first day on a tpu: xla, jax, and why anthropic's compiler bug happened" | After the burst |
| M11 | "firmware ops for sres: tracking driver/firmware compatibility without a soldering iron" | When M11 is done |
| M12 | "what does a million claude-equivalent tokens cost? a homelab-to-fleet tco model" | When M12 is done |
