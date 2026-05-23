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

```bash
git clone https://github.com/binarysquadd/frit.git && cd frit

# Provision a fresh Lightning.ai T4 Studio
make setup

# Verify GPU health
make checklist

# Stream GPU metrics
make metrics

# Run a chaos experiment
make chaos-memory
```

Requires a Lightning.ai Studio with a T4 GPU (GPU Only, no IDE).

---

## Stack

- **GPU** — Tesla T4, 16GB VRAM, CUDA 13.0
- **Inference** — vLLM, LiteLLM, Open WebUI
- **Observability** — DCGM, Prometheus, Grafana, Alertmanager, Loki
- **Custom tooling** — Go NVML exporter, chaos injector CLI, load tester
- **Platform** — Lightning.ai (free tier T4)

---

## Session Log

Raw session notes in [`session-log.md`](session-log.md). Each session adds: what was done, what broke, what was measured.

---

MIT License — by [@75asu](https://75asu.pages.dev)
