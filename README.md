# frit

GPU reliability engineering at homelab scale. One GPU VM. The full inference stack: vLLM, LiteLLM, Open WebUI, DCGM. Real SLOs, chaos experiments, postmortems. One GPU practicing patterns that hold at 1000.

**Status:** M0 done · M2 core done (DCGM → Prometheus → Grafana live) · M3 in progress — [75asu.github.io/frit](https://75asu.github.io/frit)

---

## What This Is

A public OSS project that demonstrates production-grade GPU reliability engineering on a single NVIDIA GPU VM. Every milestone ships a real artifact and a blog post.

| Anthropic Stack | Frit Equivalent |
|-----------------|----------------|
| Claude.ai | Open WebUI |
| Claude API | LiteLLM proxy |
| Claude model | vLLM + Qwen3-4B on a T4 |
| Observability | DCGM + Prometheus + Grafana |

---

## Milestones

| # | Name | Status |
|---|------|--------|
| M0 | GPU Foundation — driver, DCGM, Docker GPU passthrough, k3s | **done** |
| M1 | GPU Metrics Exporter — NVML → Prometheus, custom Go binary | queued |
| M2 | DCGM + Observability Stack — Grafana dashboards, Alertmanager rules | **done (core)** |
| M3 | Inference Layer + Token Path — vLLM + LiteLLM + Open WebUI, TTFT dashboard | **in progress** |
| M4 | SLOs + Alerting — error budgets, burn rate alerts | queued |
| M5 | Multi-Platform Simulation — canary routing, equivalence validation | queued |
| M6 | Load Testing — ramp/soak/spike, breaking point documented | queued |
| M7 | Chaos + Postmortems — 5 experiments, 3 blameless postmortems | queued |
| M8 | Cadence + OSS Contributions — 12 ops reviews, 2 merged OSS PRs | queued |

---

## Quick Start

Bring any **NVIDIA GPU VM** (a GCP Spot T4 is the reference; any Ubuntu host with a GPU works). The base layer goes from a bare VM to a running, observable inference stack — and `make teardown` wipes it back to bare, no residue.

### Prerequisites

- Your machine: `ansible`, `gcloud` (for the GCP-VM path), and an SSH key.
- A GPU VM you can SSH to with sudo. On GCP: an `n1-*` instance with `--accelerator nvidia-tesla-t4` (the driver is installed for you by `make gpu`).
- No secrets touch git — the `.env` and rendered inventory are gitignored.

### 1. Configure

```bash
git clone https://github.com/75asu/frit.git && cd frit
cp .env.example .env       # fill in GCP_PROJECT/ZONE/VM_NAME + TARGET_USER/SSH_KEY_PATH + secrets
```

### 2. Bring it up (0 → 100)

```bash
make connect    # start the VM, resolve its live IP, preflight (SSH + sudo + GPU present)
make gpu        # NVIDIA driver + nvidia-container-toolkit + DCGM + Docker (reboots once to load the driver)
make cluster    # k3s + Helm + Go, then Gitea + Flux + Vault + ESO -> Flux applies gitops/
# or just: make up   (connect + gpu + k3s + bootstrap in one shot)
```

### 3. Use it

```bash
make metrics                    # live GPU stats over SSH
make tunnel                     # forward the k3s API (keep open), then:
make kubectl CMD="get pods -A"  # talk to the cluster from your Mac
make chaos-memory               # fill GPU VRAM and observe
```

### 4. Stop / wipe

```bash
make down       # stop the VM — billing stops, disk + cluster persist (make up restores it)
make teardown   # 100 -> 0: remove k3s + GPU stack back to bare Ubuntu, no residue
```

---

## Layout

```
.env.example          VM coords + secrets (copy to .env — gitignored)
bin/                  vm.sh (VM lifecycle) · render-inventory.sh (live-IP inventory)
ansible/
  ansible.cfg         tuned SSH multiplexing / forks / accept-new host keys
  inventory/          hosts.yaml (generated, gitignored)
  playbooks/          preflight · gpu · k3s · bootstrap · site · teardown
  roles/              (future: gpu/k3s extracted into roles)
gitops/               the lab, applied by Flux: gpu-operator, vLLM, monitoring, langfuse...
Makefile              one command per step
```

## Stack

- **GPU** — NVIDIA T4 (16 GB VRAM); any NVIDIA GPU works
- **Inference** — vLLM, LiteLLM, Open WebUI
- **Observability** — DCGM, Prometheus, Grafana, Alertmanager, Loki
- **Custom tooling** — Go NVML exporter, chaos injector, load tester
- **Platform** — k3s + Flux (GitOps) on a single GPU VM

---

MIT License — by [@75asu](https://75asu.pages.dev)
