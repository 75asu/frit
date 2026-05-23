# JD Analysis: What the Market Actually Requires (May 2026)

Nine JDs reviewed: Anthropic AIRE London, Together AI Amsterdam, Together AI SF, Lightning AI GPU & Compute, Lightning AI Storage, Lightning AI Infra Ops, Google AI/ML Infrastructure (Warsaw), Google Vertex AI 3P SRE (Warsaw), and the baseline Anthropic JD already analyzed above.

**The framing shift:** The goal is not to hit Anthropic AIRE in 6 months. The goal is to identify what all AIRE-adjacent companies require, close the closable gaps in the next 6 months, and have the right resume when applying to visa-sponsoring UK companies later. The analysis below serves that.

---

## Skill Taxonomy: Three Tiers

### Tier 1 - Baseline SRE (required by every company in this list)

| Skill | Evidence |
|---|---|
| Linux in production | All 9 JDs. Lightning Infra Ops: 8yr minimum. |
| Ansible + Terraform | Together AI, Lightning Infra Ops, multiple others. |
| Kubernetes operations | Together AI, Lightning, Google. |
| Python and/or Go for automation | All JDs. Go preferred for performance tooling. |
| Prometheus + alerting | All JDs. Google uses Monarch/Automon internally. |
| On-call + incident response | Explicitly called in Anthropic, Together AI, Google. |
| Distributed systems fundamentals | Google 3P SRE: 3yr hard requirement. |

Current status: strong on Python/Go, Prometheus, K8s, Terraform, Ansible. Incident response is homelab-only - no production blast radius yet.

---

### Tier 2 - AI-Specific Differentiators (4-6 companies)

| Skill | Who requires it | Current gap |
|---|---|---|
| GPU observability - DCGM/NVML | Lightning GPU & Compute (REQUIRED), Anthropic (preferred) | No production DCGM yet. T4 lab started. |
| Inference serving operations - vLLM/TGI | Anthropic, Lightning, Google AI/ML | Not deployed vLLM in any form yet. |
| ML infra - model deployment/eval/optimization | Google AI/ML Infrastructure (3yr REQUIRED) | Hard gap. Cannot simulate in 6 months. |
| SLOs for LLM serving / token path | Anthropic (core requirement) | Can design on paper; no prod workloads yet. |
| Bare-metal operations - PXE, IPMI, Redfish | Lightning GPU & Compute, Lightning Infra Ops | No physical hardware. Cannot close without employer. |
| InfiniBand / NVLink / RDMA | Lightning GPU & Compute, Anthropic (preferred) | Cannot simulate. Requires real cluster. |
| Distributed storage - VAST, Ceph, NFS at scale | Lightning Storage (REQUIRED), Lightning Infra Ops | No Ceph hands-on. VAST is proprietary. |
| Chaos engineering - fault injection | Anthropic (preferred), can differentiate elsewhere | Planned in Frit. Closable. |

---

### Tier 3 - Staff / Advanced Signals (Anthropic + Google only)

| Skill | Context |
|---|---|
| SLOs specifically for TTFT, throughput, token path | Anthropic AIRE core. Highly specific to inference workloads. |
| Multi-region, multi-cloud HA for inference | Anthropic core. Requires cross-cloud Kubernetes + failover. |
| >1000 GPU fleet operations | Anthropic "strong candidates." Employer-gated, no shortcut. |
| Multi-accelerator fleet - H100, TPU, Trainium | Anthropic preferred. Highly employer-gated. |
| Chaos engineering designed for AI - GPU OOM, thermal throttle, driver hang | Anthropic preferred. Partially closable with T4 lab. |
| AI-specific observability - token path metrics, model health signals | Anthropic core. Closable: design and build in Frit. |
| OSS contributions - vLLM, DCGM exporter, NVIDIA device plugin | Anthropic preferred. Closable with intentional targeting. |
| Incident command at large blast radius | Employer-gated. Cannot simulate convincingly. |

---

## Company Bar Analysis (Honest Readiness Estimates)

**Together AI Amsterdam**
- Role type: SRE generalist. No AI-specific hard requirements.
- What they want: Ansible expert, Terraform, K8s, Python/Go, monitoring, on-call culture.
- What we have: Most of this. The gap is breadth of on-call experience and Ansible at depth.
- Readiness: ~70%
- Closable to ~80%+ in 6 months by: shipping platform-zero (shows Terraform/K8s depth), publishing ops postmortems, getting one Ansible contribution visible.
- **Target: apply in 3-4 months after platform-zero is further along.**

**Google Vertex AI 3P SRE (Warsaw)**
- Role type: SRE for the stack that serves Anthropic's Claude on Vertex AI. GKE-based.
- What they want: 5yr dev, 3yr distributed systems, 2yr technical leadership, load balancing, HA, scalable systems, Monarch/Automon monitoring.
- What we have: distributed systems foundation, K8s, Prometheus. Missing: GKE hands-on at depth, Google-internal tooling (untestable externally), technical leadership signal.
- Readiness: ~65%
- Closable to ~75% by: GKE-specific work (can add to awslab or Frit), architecture decision docs in public repos, any published postmortems showing incident command.
- **Target: apply in 3-4 months. Warsaw is open to non-EU; visa situation needs separate research.**

**Lightning AI Infra Ops**
- Role type: Infra generalist with GPU server exposure preferred.
- What they want: 8yr Linux, 5yr AWS, 2yr K8s, 2yr Terraform/Ansible, 2yr NAS (NFS/Ceph/VAST), Prometheus/ELK, Python/Go, InfiniBand nice-to-have.
- What we have: AWS, K8s, Terraform, Prometheus, Python/Go. Missing: 8yr Linux signal (hard to prove without work history), NAS/distributed storage.
- Readiness: ~50%
- **No visa sponsorship. Skip for now unless situation changes.**

**Google AI/ML Infrastructure (Warsaw)**
- What they want: 3yr ML infra (model deployment, eval, optimization, debugging). GPU/TPU distributed computing. Performance profiling of AI/ML workloads.
- What we have: infrastructure, not ML infrastructure. The 3yr ML infra requirement is the hard blocker.
- Readiness: ~35%
- This is the wrong role for the next 6 months. Come back in 2+ years.

**Lightning AI GPU & Compute**
- What they want: DCGM hands-on REQUIRED, PXE/IPMI/Redfish bare-metal REQUIRED, InfiniBand/NVLink preferred.
- What we have: T4 lab started. DCGM not yet installed.
- Readiness: ~25%
- **No visa sponsorship. And the bare-metal requirement cannot be faked.**

**Anthropic AIRE Staff**
- What they want: everything in Tier 3 above, plus Staff-level leadership, plus the "strong candidates" checklist.
- What we have: SRE foundation. That's it.
- Readiness: ~20%
- This is the target to build toward over 12-24 months, not 6.

---

## 6-Month Gap Breakdown

### Closable in 6 months (with intentional work)

| Gap | How to close | Project |
|---|---|---|
| GPU observability - DCGM/NVML hands-on | Install DCGM on T4, write Go binary exposing NVML metrics, Prometheus scrape | Frit |
| Inference serving operations | Run vLLM on T4, measure TTFT and throughput, write SLOs around it | Frit |
| SLO design for inference workloads | Design token path SLOs, publish as architecture doc, implement in Frit | Frit |
| Chaos engineering on GPU | Run chaos-memory, chaos-thermal experiments. Write blameless postmortems. | Frit |
| AI-specific observability | Token path dashboard, per-hop latency, SDK-to-GPU trace | Frit |
| OSS contribution | Target: one merged PR to vLLM, DCGM exporter, or NVIDIA device plugin | public |
| Architecture depth signal | Platform-zero completion: 24+ module Terraform system, documented decisions | platform-zero |
| Ansible depth | Ship awslab configuration entirely via Ansible playbooks | awslab |

### Cannot close in 6 months without an employer

| Gap | Why |
|---|---|
| Bare-metal (PXE, IPMI, Redfish, iDRAC) | Requires physical hardware. No cloud substitute. |
| InfiniBand at real cluster scale | Requires multi-node GPU cluster. Cost: $50K+. |
| VAST storage | Proprietary. Only available inside companies using it. |
| >1000 GPU fleet operations | Scale is employer-gated by definition. |
| Real incident command at large blast radius | Production traffic stakes cannot be simulated. |
| 8yr Linux proof | Work history is the only proof. |

---

## Honest 6-Month Target

**Apply to: Together AI Amsterdam and Google Vertex AI 3P SRE (Warsaw).**

Not Anthropic. Not Lightning AI GPU & Compute. Those require employer-gated gaps that cannot be closed independently.

Together AI Amsterdam is the higher-probability target: SRE generalist role, no AI-specific hard blockers, platform-zero directly demonstrates the infra depth they want.

Google Vertex AI 3P SRE is worth targeting because the role literally serves Anthropic's Claude. Getting that job is one step removed from AIRE - it builds the right resume for the London AIRE application in 12-18 months.

The path:
1. Close DCGM + vLLM + chaos gaps in Frit over next 3 months
2. Ship platform-zero to completion (all 24 modules, documented)
3. Land one OSS PR in an AI infra project
4. Apply Together AI Amsterdam + Google Warsaw at month 3-4
5. If either lands: work toward visa sponsorship for UK roles after 12 months at the company
6. Revisit Anthropic AIRE London at 18-24 months with employer-gated gaps filled
