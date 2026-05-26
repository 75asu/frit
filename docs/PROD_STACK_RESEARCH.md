# Production Inference Stack Research
_Last updated: 2026-05-26 — sourced from engineering blogs, postmortems, case studies_

This document records what frontier AI labs and GPU cloud operators actually run in production.
It informs every architectural decision in frit. When in doubt about a tool choice, come here first.

---

## The Ground Truth Table

| Company | Orchestration | Inference engine | Observability | Routing |
|---|---|---|---|---|
| OpenAI | AKS (full k8s, 7,500+ nodes) | Custom (not disclosed) | DCGM + Prometheus + Grafana + GPU health CronJobs | Custom gang scheduler, Azure CNI (no VXLAN overlay) |
| Anthropic | Multi-cloud k8s (AWS/GCP) | JAX + XLA — fully custom, no vLLM | Internal evals pipeline (admitted insufficient) | Context-window-aware custom router; sticky sessions; canary groups |
| CoreWeave | CKS — bare-metal k8s | vLLM / SGLang via Helm | Prometheus + Grafana | llm-d — prefix-aware, KV-cache-aware routing; Traefik ingress; KEDA autoscaling |
| Together AI | Not disclosed | Fully custom engine — 3x faster than vLLM; ThunderMLA attention kernels | Not disclosed | Not disclosed |
| Cursor | Azure k8s (they are a customer, not an operator) | Fireworks (FireAttention) + Together AI (TensorRT-LLM + NVFP4 on Blackwell) | Datadog + Sentry + PagerDuty | Not disclosed |
| Fireworks AI | Cloud k8s (multi-cloud) | Custom FireAttention kernels | Not disclosed | Custom compound router (f1 system) |

---

## Key Findings Per Layer

### Orchestration

Full upstream Kubernetes everywhere at production scale. No k3s in any production workload
mentioned across all sources. Docker Compose appears only in dev/tutorial contexts.

- OpenAI: AKS — moved from Flannel/VXLAN to Azure CNI for pod-to-pod latency at scale
- CoreWeave: CKS — bare-metal k8s, BlueField DPUs offload networking off the GPU
- etcd on local NVMe SSDs (OpenAI) — network-attached storage caused 2ms latency;
  local SSD dropped it to 200 microseconds

**For frit (single T4 VM):** k3s is the correct single-node analog. Same toolchain
(Helm, kubectl, GPU device plugin), minimal control-plane overhead (~500MB RAM).

---

### Inference Engine

Neither Anthropic nor OpenAI uses vLLM. Both built custom model servers.

- Anthropic: JAX + XLA. The XLA compiler generates hardware-specific code for TPU/GPU/Trainium.
  Their September 2025 postmortem revealed three overlapping bugs in this custom stack —
  routing misconfigurations, TPU runtime corruption, and an XLA compiler miscompilation.
- OpenAI: not disclosed. Likely custom.
- Together AI: fully custom engine, explicitly benchmarks against and beats vLLM 3x on throughput.
- CoreWeave: recommends vLLM and SGLang to customers. Contributed Tensorizer (fast model weight
  loading format) to vLLM. Also backing llm-d (CNCF Sandbox).

**vLLM is the open-source standard.** Used and recommended by CoreWeave, backed by the broader
CNCF community via llm-d. The vLLM production-stack (github.com/vllm-project/production-stack)
is the canonical reference architecture: Helm-first, supports prefix-aware routing, KV cache
metrics, multi-model deployments.

**For frit:** vLLM is the right call. It is what a GPU cloud operator (CoreWeave) deploys for
its customers. The production-stack Helm chart is the deployment method.

---

### Observability

OpenAI is the only company to have publicly confirmed their observability stack in detail:

- DCGM (Data Center GPU Manager) across all GPU nodes
- NVML for per-device metrics
- dcgm-exporter → Prometheus → Grafana
- Selective metric scraping (not all DCGM metrics) to control data volume
- Kubernetes CronJobs that fire on random nodes, run custom CUDA diagnostic tests,
  cordon unhealthy nodes before any workload lands — this is active health management,
  not just passive metrics

Anthropic's admission from their September 2025 postmortem: they lacked "sensitive enough
degradation detection benchmarks" and had no continuous production quality evaluations.
Three bugs ran undetected for days to weeks because their observability was insufficient.

Cursor (as a customer/consumer): Datadog, Sentry, PagerDuty, Amplitude. This is the
application-layer observability stack, not the GPU infra stack.

**LiteLLM is NOT used by any frontier lab as an infra component.** It is an API-routing proxy
used by teams consuming inference APIs, not by teams operating them. Known performance issues
at scale: 500 microsecond overhead per request, memory leaks under sustained load. Useful as
a developer gateway layer but should not be framed as "what Anthropic uses."

**Langfuse is NOT an infra-layer tool.** It is a developer observability product for teams
building applications on top of inference APIs (LLM traces, prompt management, evals). ClickHouse
acquired Langfuse (2025/2026). Useful one layer above what AIRE does.

**For frit:** kube-prometheus-stack (Prometheus + Grafana + Alertmanager) via Helm + DCGM
exporter (via GPU Operator or standalone). Add GPU health CronJob. Track vLLM-native metrics:
TTFT, TBT (time between tokens), KV cache hit rate, request throughput.

---

### Routing

The most sophisticated layer — and the source of Anthropic's biggest incident in 2025.

- Anthropic: custom context-window-aware router. Short-context and long-context requests go to
  separate server pools configured for different memory layouts. Sticky routing (session affinity).
  Canary groups for staged rollouts. The August 2025 routing bug misrouted 16% of Sonnet 4
  requests to 1M-token servers for 11 days before detection.
- CoreWeave / llm-d: prefix-aware routing (route to the node that already holds the KV cache
  for the given context prefix — avoids redundant recomputation). Also supports
  prefill/decode disaggregation (separate nodes for prefill vs. autoregressive decode).
- vLLM production-stack: five routing strategies — round-robin, session-based, prefix-aware,
  KV-cache-aware, disaggregated-prefill.

**For frit:** vLLM's built-in routing (prefix-aware mode) + Traefik as ingress (built into k3s).
No LiteLLM needed at the routing layer. The routing behavior to simulate is: prefix-aware routing
(KV cache hits), sticky sessions, and canary traffic splitting — all available in vLLM
production-stack or via Traefik weighted routing.

---

### Model Weight Storage and Loading

This is the operational detail nobody documents but everyone hits at scale.

- Fireworks AI: weights in GCS/S3 as cold store. 100+ GPU replicas simultaneously pulling an
  800 GB model saturated ingress bandwidth — 20-60+ minute cold starts. Solution: Alluxio
  distributed cache on local NVMe SSDs co-located with GPU nodes. Results: 800 GB model at
  100+ replicas loads in 2-3 minutes. Cache hit ratio: 90-100%.
- CoreWeave: Tensorizer format (contributed to vLLM) for fast weight loading from PVCs.
  ReadOnlyMany PersistentVolumes allow multiple inference pods to share the same weight files.

**For frit:** Model weights stored at `/teamspace/studios/this_studio/models/` — this path
persists across Lightning.ai studio restarts (maps to the "hot cache" tier in production).
vLLM reads weights from this path at startup. No re-download on studio restart.

---

## What This Changes in the Frit Plan

| Previous assumption | Corrected by research |
|---|---|
| Docker Compose is the deployment method | k3s + Helm is the production-equivalent approach; Docker Compose is dev only |
| LiteLLM is the "Claude API equivalent" | LiteLLM is a dev proxy; vLLM's own routing handles production-pattern behavior |
| Langfuse is an infra-layer observability tool | Langfuse is an application-layer tool (one layer above what AIRE does) |
| DCGM is optional / advanced | DCGM is what OpenAI runs in production — it is the baseline, not optional |

---

## Primary Sources

- OpenAI: [Scaling Kubernetes to 7,500 Nodes](https://openai.com/index/scaling-kubernetes-to-7500-nodes/) (2021)
- Anthropic: [A Postmortem of Three Recent Issues](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues) (Sep 2025)
- CoreWeave: [Deploy vLLM for Inference — Docs](https://docs.coreweave.com/products/cks/tutorials/deploy-vllm-inference)
- CoreWeave: [Red Hat AI Inference on CKS](https://wf.coreweave.com/blog/red-hat-ai-inference-on-cks-for-hybrid-inference)
- Together AI: [Inference Engine v1](https://www.together.ai/blog/together-inference-engine-v1)
- Together AI: [Cursor Partnership / Blackwell](https://www.together.ai/blog/learn-how-cursor-partnered-with-together-ai-to-deliver-real-time-low-latency-inference-at-scale)
- Cursor: [ByteByteGo — How Cursor Serves Billions](https://blog.bytebytego.com/p/how-cursor-serves-billions-of-ai)
- Fireworks AI: [Alluxio Case Study](https://www.alluxio.io/customer-stories/fireworks-ai-accelerates-inference-cold-starts-across-multiple-gpu-clouds-with-alluxio)
- vLLM: [Production Stack Release Blog](https://vllm.ai/blog/2025-01-21-stack-release)
- vLLM: [Production Stack GitHub](https://github.com/vllm-project/production-stack)
- llm-d: [llm-d.ai](https://llm-d.ai)
