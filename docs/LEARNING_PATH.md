# GPU SRE Learning Path

---

## GPU SRE Learning Path: Starting Point

The domain is not as foreign as it looks. GPU architecture is new. The job - metrics, SLOs, alerts, chaos, postmortems - is the same SRE work. What changes is the substrate.

### The Mental Model: Four Layers

```
Layer 4 — SRE principles (existing skillset)
Layer 3 — Inference serving / workload (vLLM)
Layer 2 — GPU software stack (DCGM, NVML, dcgm-exporter)
Layer 1 — GPU hardware basics (what breaks, what to measure)
```

Learn bottom-up. Operate top-down.

---

### Layer 1: Hardware (one session, not a course)

For SRE purposes, a GPU is a device with four things that can fail or saturate:
- Its own memory (VRAM)
- Its own compute units (CUDA cores / Streaming Multiprocessors)
- Its own temperature and power envelope
- A driver between it and the OS

**The five metrics that actually matter for GPU SRE:**

| Metric | What it tells you | Failure mode |
|---|---|---|
| `gpu_utilization` | Is the GPU doing work or sitting idle | Idle under load = bad scheduling or stalled pipeline |
| `memory_used / memory_total` | VRAM consumption | OOM = job crash, no warning |
| `temperature` | Thermal state | T4 throttles above ~83C, shuts off above 90C |
| `power_draw` | Sustained load signal | T4 max 70W. Near-max sustained = thermal risk |
| `ecc_errors` | Memory bit flips | T4 has no ECC. A100+ only. |

Nothing else in the first three sessions. These five drive every alert and chaos experiment that follows.

---

### Layer 2: Software Stack

```
Your workload (vLLM, Go binary, etc.)
        ↓
CUDA runtime
        ↓
GPU driver (NVIDIA kernel module)
        ↓
NVML — C API that talks to the driver
        ↓
DCGM — wraps NVML, adds grouping, health checks, profiling
        ↓
dcgm-exporter — exposes DCGM metrics as Prometheus scrape endpoint
```

Operating position: DCGM and above. NVML is useful for writing a custom Go binary (one session). DCGM is what you actually operate day-to-day.

Session 2 goal: install DCGM, run `dcgmi discovery`, confirm it sees the T4, start `dcgm-exporter`, curl the Prometheus endpoint. That single session takes the setup from "I know GPUs exist" to "I have GPU metrics in Prometheus."

---

### Layer 3: Inference Serving (the workload to observe)

GPU SRE without a workload is like network SRE without traffic. The workload is vLLM.

vLLM is the standard open-source inference server. It runs an LLM model, accepts HTTP requests, returns tokens. Start with a tiny model so the T4's 16GB VRAM is not exhausted:

```bash
docker run --gpus all \
  -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model facebook/opt-125m \
  --max-model-len 512
```

`opt-125m` is ~250MB. Loads in seconds. Not useful for production - useful for generating tokens to observe.

**Two metrics from the workload that matter for SLO design:**

- **TTFT (Time To First Token):** how long from request submission until the first token appears. This is what users feel as latency.
- **Throughput:** tokens per second. This is what determines how many concurrent users the system can serve.

These are not generic latency metrics. They are inference-specific. Almost nobody outside of inference-serving companies knows how to set SLOs around them. That's the differentiator.

---

### Layer 4: SRE on Top (existing domain, new substrate)

| SRE concept | GPU / inference form |
|---|---|
| SLIs | TTFT p99, throughput tokens/sec, request error rate |
| SLOs | TTFT p99 < 500ms on 99.9% of requests over 30min rolling window |
| Error budgets | Same burn rate calculation, same alerting math |
| Alerts | `gpu_memory_used > 90%` = page; `TTFT p99 > 1s` = page |
| Chaos | Fill VRAM with competing process, observe TTFT degradation, kill driver |
| Postmortems | Same blameless format, GPU-specific failure modes |

---

## What Staff-Level SRE Experience Actually Means (And How to Simulate It)

Staff is two levels above Senior. A Staff SRE hasn't just seen more -- they've made decisions that Senior engineers haven't faced. Here's what that really means, and how to close each gap.

### 1. Scale-Induced Failure Modes

**What a Staff SRE has seen:** At 1000 GPUs, failures are statistical certainties, not anomalies. GPU ECC errors accumulate silently across the fleet. NCCL ring topology develops congestion under specific all-reduce patterns. InfiniBand fabric has partitioned nodes that still respond to ping but drop every 3rd RDMA packet. These failure modes don't exist at 1-10 GPU scale. You can't see them without the fleet.

**How to close the gap:** You can't experience them, but you can KNOW them. Read every public GPU infrastructure postmortem from Anthropic, Google, Meta, NVIDIA. Study NCCL failure patterns. Understand the top 10 failure modes in GPU fleets: ECC errors, thermal throttle, NVLink degradation, PCIe retraining, driver hangs, memory leaks in CUDA context, InfiniBand fabric partitions, RoCE congestion control collapse, GPU process stuck in D-state. When asked in an interview: "I haven't run 1000 GPUs, but here's what I know about failure modes at that scale based on studying postmortems from X, Y, Z companies."

**Practice:** Frit chaos experiments. For each local experiment, write a companion research note: "At 1000-GPU scale, this GPU OOM would manifest as..." This builds the mental model.

### 2. Organization-Scale Reliability Strategy

**What a Staff SRE does:** Defines error budget policies for 50+ services. Designs oncall rotation structures across timezones. Sets incident severity classifications that product managers and VPs agree to. Creates the postmortem culture, not just writes postmortems. Makes reliability a shared organizational value, not an SRE team responsibility.

**How to close the gap:** Frit IS this, at 1-person scale. The SLO.md, error budget policies, ops review cadence, postmortem templates -- these are the exact same artifacts a Staff SRE produces, just for a smaller system. The thinking is identical. The scale is the only difference.

**Practice:** Write an "SRE Charter" document for Frit. Define what reliability means, what the error budget policy is, what oncall expectations are, how incidents are classified (SEV1/2/3), and how postmortems are conducted. This is a Staff-level artifact. Ship it.

### 3. System Design, Not System Operation

**What a Staff SRE does:** Architects systems that other engineers operate. Decides the scheduler design, the networking topology, the storage layer. Makes tradeoffs between consistency and availability. Understands the system deeply enough to predict failure modes before the system is built.

**How to close the gap:** Kiln IS system design. You're building a container orchestrator from scratch. Every architectural decision -- clone() vs Firecracker, gRPC vs REST, your own scheduler vs reusing K8s -- IS a Staff-level decision. Document them. Write architecture decision records (ADRs). Compare your designs to KServe, vLLM, and NVIDIA Triton. This is literally what Staff engineers do.

**Practice:** For every Kiln component, write a 1-page ADR: context, decision, alternatives considered, consequences. Publish them. A repo with 10 ADRs is a Staff-level portfolio.

### 4. Cross-Team Influence Without Authority

**What a Staff SRE does:** Drives reliability improvements across teams that don't report to them. Persuades a product team to prioritize reliability work over a feature. Negotiates error budget tradeoffs with a VP who wants to ship faster. Builds trust so that when they say "we need to slow down," people listen.

**How to close the gap:** Hardest to simulate solo. Two proxies:

- **OSS contributions.** Getting a PR merged into NVIDIA device plugin requires persuading maintainers who owe you nothing. Iterating on feedback. Building consensus. This IS cross-team influence.
- **Public writing.** An architecture blog post that gets shared and discussed teaches you to communicate technical decisions to an audience you don't control. Responding to comments, defending tradeoffs -- this is the soft skill Anthropic wants.

**Practice:** After every Frit chaos experiment, write a public postmortem. Share it on LinkedIn, HN, relevant Discords. Defend your decisions in the comments. Build the muscle of public technical reasoning.

### 5. Financial and Business Thinking

**What a Staff SRE does:** Makes build-vs-buy decisions at $1M+ scale. Understands TCO of a GPU cluster over 3 years. Models capacity planning against projected user growth. Knows when spending $500K on a custom scheduler saves $2M in GPU costs over 2 years.

**How to close the gap:** Include cost analysis in every Frit and Kiln design doc. Even at 1-GPU scale, practice the thinking:

> "At 1000 GPUs, this nginx load balancer would cost $X/month in compute. A commercial alternative would cost $Y. The build-vs-buy breakeven is at Z GPUs. I chose nginx because..."

**Practice:** Write a "Cost Model" doc for Kiln at scale. What would it cost to run Kiln for 10,000 sandboxes on 50 GPU nodes? Model compute, network, storage, and staffing. This is a Staff-level artifact.

### 6. Incident Command at Massive Blast Radius

**What a Staff SRE does:** Commands incidents where the blast radius is millions of users and millions in revenue. Makes the call to roll back a deployment that 50 engineers shipped over 3 weeks. Communicates status to C-suite while debugging kernel panics. Stays calm when everything is on fire.

**How to close the gap:** Can't simulate the pressure. But CAN simulate the process.

- Frit chaos experiments with structured incident response: declare severity, assemble (virtual) response team, communicate status, resolve, write postmortem.
- Time-limit yourself: "GPU is down, users are impacted. You have 5 minutes to communicate status, 15 minutes to resolve."
- Write a "communication to VP" as part of every postmortem. What would you tell the CTO?
- Role-play the PM conversation: "You burned 30% of this month's error budget in 10 minutes. The PM wants to ship a feature tomorrow. What do you say?"

**Practice:** The postmortem template should include a "Leadership Communication" section: what was communicated, to whom, when. This builds the muscle of structured crisis communication.

### 7. The Google Paradox (Your Hidden Advantage)

A Staff SRE who spent 14 years at Google has seen massive scale. But Google provides:
- Pre-built SLO frameworks (they don't design them)
- Pre-built incident management (they don't build it)
- Pre-built monitoring infrastructure (they don't architect it)
- Pre-built oncall structures (they don't create them)

They operate within existing systems. They rarely build them from scratch.

You, building Frit from nothing, are designing the frameworks. SLO.md from scratch. Postmortem templates from scratch. Ops review cadence from scratch. This IS more Staff-level thinking than plugging into Google's pre-built infrastructure, even at 1000x smaller scale.

When the interviewer asks "have you designed an SLO framework?" -- the Googler says "I used Google's." You say "Here's my SLO framework. I designed it. Here are the tradeoffs I made. Here's how I'd adapt it for Anthropic."

The Googler wins on scale. You win on demonstrated design thinking. Both matter. But for a role that's building a new reliability function from scratch (AIRE is only months old, their head was fired in January, the team is being built NOW), the person who can design frameworks might be more valuable than the person who's only ever operated within them.

### Summary: The Gap-Filling Plan

| Gap | How to Fill | Timeline | Artifact |
|-----|-----------|----------|----------|
| Scale failure modes | Study postmortems + companion notes for each Frit experiment | Months 1-6 | Research notes + chaos writeups |
| Org reliability strategy | SRE Charter, SLO.md, error budget policies, ops review cadence | Month 2-3 | SRE Charter doc |
| System design | Kiln ADRs + architecture design docs comparing to KServe/vLLM | Ongoing | 10+ ADRs |
| Cross-team influence | OSS PRs + public writing + defending decisions publicly | Months 3-12 | Merged PRs, blog comments |
| Financial thinking | Cost models in every design doc | Ongoing | Cost Model doc |
| Incident command | Timed chaos experiments + leadership communication in every postmortem | Monthly | Postmortems with comms section |
| Framework design | All of the above, designed from scratch | Ongoing | Frit repo |

None of this requires a job at Google. All of it produces public proof. When you apply to Anthropic AIRE in 3-4 years, you don't hand them a resume. You hand them a GitHub org with 5+ repos, 50+ postmortems, 10+ ADRs, merged OSS PRs, and a documented reliability practice. That portfolio beats a 15-year Google resume because it proves you can DO the work, not just that you've BEEN somewhere.

---

## Compressing the Timeline

The gap analysis says 3-4 years. That's the conservative estimate. The optimistic scenario is 2-2.5 years if the intermediate step goes well.

**What signals "Staff" and how fast each is acquirable:**

| Staff signal | Typical path | Compressed path |
|---|---|---|
| Fleet debugging experience | Work at FAANG 10 years | 12-18 months at CoreWeave/Lambda on a real GPU fleet |
| SLOs/error budgets designed from scratch | Built at scale over years | Frit + intermediate role, documented publicly |
| Cross-team influence | Built over years at one company | OSS maintainer status - forces persuading strangers who owe you nothing |
| Incident command at real blast radius | Real incidents over years | Genuine fleet role, no shortcut |
| Framework design (not just operation) | Google gives you the framework | Building Frit from scratch IS this |
| Financial/TCO thinking | Years of build-vs-buy decisions | Write cost model docs now, practice the thinking deliberately |

**The one thing you cannot shortcut:**

Fleet experience. Anthropic will ask about a real incident at scale - a thermal throttle cascade across 200 nodes, NCCL ring topology breaking under a specific all-reduce pattern, a driver hang nobody else has seen. You need to have actually been in that war room. No amount of homelab practice or postmortem reading substitutes for having debugged it at 3am on a real fleet.

That's the single gap requiring the intermediate role. Everything else in the table above is compressible.

**The compressed path (optimistic: 2-2.5 years):**

1. **Now - 12 months:** Build the portfolio. Get Senior GPU SRE at CoreWeave, Lambda, Nebius, or a frontier-adjacent lab (Cohere, Mistral). Their fleets are smaller than Anthropic's but real. Less competitive to get in than Anthropic directly.

2. **12-24 months:** Go deep. Real 3am GPU incidents. Real RDMA debugging. Real fleet health decisions. Push for Staff internally - at a GPU cloud company this timeline is faster than general SRE because the domain is narrow and people who know it are scarce.

3. **24-30 months:** Apply to Anthropic as Staff GPU SRE at [real GPU cloud company] + public portfolio. That combination at 8-9 YOE beats a 14-year Google SRE with no GPU experience.

YOE is a filter, not a ceiling. What actually matters at the interview: can you answer the incident questions, can you explain the tradeoffs, can you point to artifacts. An 8-year candidate with 2 years of real GPU fleet experience and a public portfolio beats a 14-year Googler who plugged into Google's pre-built frameworks and never designed one from scratch.

---

## Key Reading & References

### Systems Thinking
- cpu.land (Danny Lin) -- CPU internals for systems engineers
- Brendan Gregg's "Systems Performance" -- the SRE-SE bible
- Google SRE Book -- the original archetype definitions

### GPU Architecture & Infrastructure
- NVIDIA DCGM docs -- GPU metrics and health monitoring
- NVML API reference -- programmatic GPU management
- NCCL docs -- collective communications for distributed training
- NVIDIA GPU Operator for Kubernetes -- how big shops run GPUs in K8s

### GPU Kernels (Adjacent Knowledge)
- Flash Attention 1-4 paper series -- understand the memory bottleneck problem
- ThunderKittens DSL -- kernel development abstraction
- Triton documentation -- the Python DSL for GPU kernels
- Vlad Feinberg's "How to Land a Frontier Lab Job" -- the kernel work path

### Distributed Training
- "How to Train Really Large Models on Many GPUs" (Lil'Log)
- DeepSpeed and FSDP architecture overviews
- Meta's "Scaling AI Training Infrastructure" engineering blog posts

---

## FAQ: Getting Started With GPUs

### Can I use Google Colab?

No. Colab gives you a managed T4 behind a Jupyter notebook. You cannot install NVIDIA drivers, configure the container toolkit, set up DCGM, or manage scheduling. Colab is for training models, not learning GPU infrastructure. For infra work, you need root access to a physical or virtual machine with a GPU.

### Can I buy an old GPU machine locally?

Yes, and it's the best option. A used gaming PC with a GTX 1060/1070/1080 or RTX 2060 -- Rs 20,000-40,000 on OLX/used market in India. You don't need compute power. You need *a* GPU to:

- Install NVIDIA drivers from scratch
- Set up nvidia-container-toolkit
- Run nvidia-smi and parse NVML
- Configure DCGM for GPU metrics
- Pass the GPU through to a container (--gpus all)
- Monitor GPU memory, temperature, throttling, ECC errors

The learning is in the management layer, not the model speed. Any CUDA-capable GPU works. A GTX 1070 (8GB) is plenty.

### What is CUDA?

CUDA is NVIDIA's proprietary platform for programming GPUs. It has two parts:

1. A **C++ extension** that lets you write code running directly on GPU cores (called kernels)
2. A **runtime library** that manages GPU memory allocation, kernel launching, and CPU-GPU synchronization

```
CPU (host):       "GPU, take this array of 10 million numbers"
GPU (device):     "Got it. I'll multiply them all simultaneously on 10,000 cores"
CPU:              "Done? Return results"
```

CUDA exists because GPUs aren't just faster CPUs. They're a fundamentally different architecture: thousands of simple cores executing the same operation on different data simultaneously (SIMD). CUDA is the language for directing them.

For GPU infrastructure SRE work: you don't need to write CUDA kernels. You need to understand the CUDA runtime -- how GPU memory is allocated, how kernels are scheduled, what CUDA OOM errors look like. That's the infra layer.

### Why can't we do GPU programming in Go instead of C++?

Technically, you can. There are Go bindings for CUDA (e.g., mumax/ffi-based wrappers). The problem is that NVIDIA's entire ecosystem -- drivers (libcuda.so), math libraries (cuBLAS, cuDNN), communication libraries (NCCL), tooling (NSight, DCGM, nvidia-smi) -- is C++ native. Go's garbage collector and goroutine scheduler add unpredictable latency that breaks GPU memory management patterns.

For GPU **infrastructure** work (your target), Go is actually fine:
- NVML has C bindings callable from Go via cgo
- The NVIDIA device plugin for Kubernetes is written in Go
- GPU cluster schedulers, monitoring agents, and health check daemons can all be written in Go
- You just won't write the compute kernels themselves in Go

### What is JAX?

JAX is Google's alternative to PyTorch for ML research. Key differences:

| | PyTorch | JAX |
|---|---|---|
| Core idea | Imperative: loops and if-statements like normal Python | Functional: pure functions, transformations are explicit |
| GPU code | Hidden behind model.to('cuda') | Explicit via jax.jit() -> XLA compiler -> GPU/TPU |
| Primary users | Almost everyone | DeepMind, frontier AI research labs |
| Philosophy | Pythonic, easy to debug | Mathematically pure, fast, composable |

JAX doesn't target CUDA directly -- it compiles through XLA (Accelerated Linear Algebra), Google's intermediate compiler that targets both GPUs and TPUs. This is why Google's TPU ecosystem is JAX-first.

For GPU infra SRE work: JAX is relevant because frontier AI labs use it. Knowing what it is matters for understanding their infrastructure requirements. But you don't need to learn JAX to become a GPU infrastructure SRE. You need to understand what happens *underneath* JAX -- the GPU scheduling, memory management, and networking that makes JAX workloads run reliably.

### What does "know distributed" mean? (CEO's tweet)

A CEO responding to Vlad's article added: "Know distributed. Hiring people to do good work spanning more and more GPUs is hard. If you can reason through the common parallelisms, their bottlenecks, tradeoffs, impls, I'd hire you."

This refers to distributed training -- the hard problem of making training work across hundreds of GPUs:

```
One GPU:        Model fits in memory. Fast. Simple.
100 GPUs:       Split the model. Split the data. Coordinate.
                Now: communication bottlenecks, straggler GPUs,
                synchronization overhead, gradient divergence.
```

The "parallelisms" he references:

| Type | Strategy | Bottleneck |
|------|----------|------------|
| Data parallelism | Each GPU gets different batch of data, gradients synchronized at end of step | Network bandwidth (NCCL all-reduce over InfiniBand) |
| Model parallelism | Split model layers across GPUs (GPU0: layers 1-10, GPU1: layers 11-20) | Pipeline bubbles (GPUs idle waiting for upstream) |
| Tensor parallelism | Split individual matrix multiplication ops across GPUs | Extreme communication bandwidth requirements |
| FSDP / ZeRO | Shard optimizer states, gradients, and parameters across GPUs | Memory vs. communication tradeoff (recompute vs. transmit) |

This is NOT CUDA kernel writing. This is the layer ABOVE -- architecting how workloads run on GPU fleets. It's exactly where SRE meets AI infrastructure. Reasoning about straggler mitigation, network topology, failure domains, and checkpoint strategies across GPU fleets IS reliability engineering, just at a different layer.

---

## GPU Hardware: Buying Guide (India)

### Where to Buy Used GPUs / Gaming PCs (India)

**1. OLX India (olx.in)**
Search: "gaming pc" or "used pc" filtered to your city (Brahmapur/Bhubaneswar). Sort by newest, message fast -- good deals go in hours. Search in both English and local terms. Ask the seller to run nvidia-smi or GPU-Z before purchasing.

**2. Facebook Marketplace**
Open on your phone. Filter to Bhubaneswar + 40km radius. Search "Gaming PC," "PC sale," "desktop computer," or "computer bechna hai." Most sellers post with mixed Hindi/English descriptions. Message multiple sellers -- response rates vary.

**3. Zoukart (zoukart.com)**
India's largest used PC parts forum. Dedicated marketplace section with buyer/seller ratings. Less scam risk than OLX. You can find individual GPUs here and pair with any old office PC. Reputable community with fair pricing.

**4. Techenclave Forums (techenclave.com)**
Indian tech community with active classifieds section. Higher quality listings, more knowledgeable sellers. Worth posting a "WTB: Used GPU/PC under 30K" thread. Established members have reputation scores.

**5. Local Computer Market (Bhubaneswar)**
Saheed Nagar area has 15+ computer shops. Walk in, ask about used gaming PCs or trade-ins. Cash deals, no shipping, can test the machine on the spot. Shops often have old inventory they want to clear.

**6. Quikr (quikr.com)**
Similar to OLX. Smaller selection but sometimes better prices. Check both platforms for the same city.

### GPU Price Guide (Used, India, 2026)

| GPU | VRAM | CUDA | Used Price (Rs) | Notes |
|-----|------|------|-----------------|-------|
| GTX 1050 Ti | 4GB | 6.1 | 5,000-7,000 | Minimum viable. Works for NVML/DCGM learning. 4GB limits ML experiments |
| GTX 1060 6GB | 6GB | 6.1 | 7,000-10,000 | Sweet spot. Widely available, 6GB decent for small models |
| GTX 1070 | 8GB | 6.1 | 10,000-14,000 | Ideal for infra work. 8GB lets you run small PyTorch models |
| GTX 1080 | 8GB | 6.1 | 12,000-16,000 | Faster than 1070, runs hotter, more power draw |
| RTX 2060 | 6GB | 7.5 | 14,000-18,000 | Tensor cores (useful for ML), newer arch, Ray Tracing cores |
| RTX 3060 12GB | 12GB | 8.6 | 18,000-25,000 | Best value if budget allows. 12GB lets you run real models |

### Complete Build Cost Estimates

**Option A: Minimum Viable (Rs 20,000-25,000)**
- Used Dell/HP office PC (i5 4th gen, 8GB RAM): Rs 6,000-8,000
- GTX 1050 Ti or GTX 1060 3GB: Rs 5,000-8,000
- 120GB SSD: Rs 1,000
- Total: Rs 12,000-17,000 + monitor/keyboard optional

**Option B: Recommended (Rs 30,000-40,000)**
- Used gaming PC (i7 6th/7th gen, 16GB RAM): Rs 18,000-25,000
- Already includes GTX 1060 6GB or 1070
- 240GB SSD: Rs 1,500
- Total: Rs 20,000-27,000 for a complete system

**Option C: DIY Build (Rs 35,000-45,000)**
- Used i5/i7 CPU + mobo combo: Rs 12,000-15,000
- GTX 1070 / RTX 2060: Rs 12,000-16,000
- 16GB DDR4 RAM: Rs 3,000
- 500W PSU: Rs 2,500
- Case + 256GB SSD: Rs 3,500
- Total: Rs 33,000-40,000

### Pre-Purchase Checklist

Before handing over cash:

1. Ask seller to install GPU-Z or run `nvidia-smi` -- verify the GPU model and VRAM
2. Check GPU temperature at idle (should be 30-50C) and under brief load (should stay under 85C)
3. Look for physical damage: bulging capacitors, burnt smell, bent PCIe connector
4. Ask if the GPU was used for mining. Mined GPUs have degraded VRAM from 24/7 thermal cycling. Not always a dealbreaker, but negotiate 20-30% off
5. Ask age of GPU and reason for selling
6. If buying a full PC, run it for 10 minutes. Listen for fan noise, check for random reboots
7. Prefer sellers who can demo the machine working before purchase

### What You Don't Need

You are NOT buying a GPU for gaming or training large models. You don't need:
- Latest generation (40-series)
- High VRAM (24GB) for LLM inference
- Multi-GPU setups
- Fancy cooling or RGB

You need: any CUDA-capable NVIDIA GPU with root access to the host system, for learning driver installation, NVML, DCGM, container toolkit, and GPU passthrough. A Rs 10,000 GTX 1060 does everything you need.

---

## Simulating Staff-Level AIRE Locally

### The Catch-22

You need Staff-level AIRE skills to get hired at Anthropic, but you can't get Staff-level AIRE experience without already working at a frontier lab. Traditional career progression is broken because frontier labs automated away junior, mid, and senior roles. Only Staff+ survives.

The solution: build the ARTIFACTS, not the experience. What Staff SREs produce -- SLO frameworks, postmortem culture, chaos engineering discipline, architecture decision records, ops review cadence -- can be built at homelab scale. The scale differs. The thinking doesn't.

### What Staff AIRE Actually Does (Not What The JD Says)

The JD says: "Develop SLOs for large language model serving systems." What it means: design error budget policies that product and engineering teams will actually respect. That's not a technical problem. It's an organizational design problem that happens to require technical credibility.

The JD says: "Lead incident response for critical AI services." What it means: be the person who says "we're rolling this back" when 50 engineers want to keep pushing. That requires earned trust, not a job title.

The JD says: "Design and implement monitoring and observability systems across the token path." What it means: understand the token path deeply enough that you know WHICH metrics matter before you build the dashboard. Not just "instrument everything" -- "instrument the right things, ignore the noise."

These are all simulatable. Not at 1000-GPU scale. But at the thinking level.

### Five Things You Can Simulate Locally

#### 1. The Token Path Simulator

Build a system where you can observe every hop:

```
Open WebUI / Aider → LiteLLM (:4000) → vLLM (:8000) → T4 GPU
```

At each hop: latency, error rate, resource consumption. This is EXACTLY what AIRE monitors at Anthropic, just at 1/1000th the scale. The metrics are real. The failure modes are the same categories. The SLO math is identical.

What this teaches you that no course will: you discover which metrics are leading indicators vs. lagging indicators. TTFT p99 spikes before gpu_memory_used reaches 90%. If you know that from experience, you set the alert threshold 10% lower. That's the insight.

#### 2. SLO War Games

Design three rounds of SLO negotiation:
- **Round 1:** You're the SRE. Define the SLO from scratch. What's the right TTFT threshold? Why 99.9% and not 99.99%? What's the error budget policy?
- **Round 2:** You're the PM. The SRE (also you) wants to freeze deploys for 2 weeks because the error budget is at 15%. You have a feature to ship. What do you say?
- **Round 3:** You're the VP. Both the PM and SRE are in your office. Make the call.

Write this up as a doc. This is the Staff-level thinking Anthropic is looking for -- the person who designed the framework, not just the person who operates within it.

#### 3. Chaos Engineering on Your Own Infra

The chaos experiments in Frit are real chaos engineering. The scenarios are smaller, but the methodology is identical:
- Hypothesis: "If GPU memory exceeds 80%, TTFT p99 will exceed our SLO within 2 minutes."
- Method: fill VRAM with a competing process, measure TTFT.
- Observation: what actually happened?
- Conclusion: was the hypothesis correct? What does this tell us about the system?

Write this up in the format Anthropic uses for postmortems. When an interviewer asks "walk me through a chaos experiment you ran" -- you have 5 documented ones with real metrics.

#### 4. Architecture Design (Paper Exercises)

For every component in Frit, write a 1-page design doc:
- What problem does it solve?
- What alternatives did I consider?
- Why did I choose this one?
- What are the failure modes?
- At 1000x scale, what breaks first?

These are Architecture Decision Records (ADRs). A repo with 10 ADRs is a Staff-level portfolio artifact. It shows you design systems, not just operate them.

#### 5. OSS Contributions as Reconnaissance

Pick one tool in the Frit stack -- DCGM exporter, vLLM, LiteLLM -- and read its source code. Find one documentation gap, one edge case, one missing metric. File an issue. Better: submit a PR.

Getting a PR merged requires:
- Understanding the codebase deeply enough to make a correct change
- Persuading a maintainer who doesn't know you
- Iterating based on feedback
- This is cross-team influence without authority at the smallest possible scale

It's also direct reconnaissance into tools Anthropic runs at scale. When they ask "have you worked with DCGM?" -- "I have a merged PR in the dcgm-exporter" is a different answer than "I installed it and ran it."

### The Portfolio That Replaces Job Experience

After 6 months of deliberate practice:

```
Public GitHub: github.com/binarysquadd/frit
  - 5+ chaos experiments with postmortems
  - 12+ weekly ops review notes
  - SLO framework with error budget policy
  - Architecture decision records
  - Cost model at 1000-GPU scale

OSS contributions:
  - 1-2 merged PRs in DCGM exporter or NVIDIA device plugin

Blog:
  - 10+ articles on dev.to about GPU infrastructure
  - Public postmortems cited and discussed
```

This portfolio answers every question in the Anthropic AIRE interview:
- "Have you designed SLOs from scratch?" → yes, here's SLO.md
- "Have you done chaos engineering?" → yes, here are 5 documented experiments
- "Do you run ops reviews?" → yes, here are 12 weekly notes
- "Have you contributed to GPU tooling?" → yes, here's the merged PR
- "Can you think at scale?" → yes, here's a cost model for 1000 GPUs

### The Honest Timeline

The portfolio does NOT get you to Anthropic AIRE in 6 months. That requires the intermediate step (real GPU fleet experience at CoreWeave, Lambda, Nebius).

What the portfolio gets you in 6 months: qualified to apply and likely to pass the screen at Together AI Amsterdam, Google Vertex AI 3P SRE Warsaw, and similar AIRE-adjacent roles that sponsor UK visas.

What it gets you in 12-18 months (after landing one of those): the foundational experience + real fleet exposure = ready to apply to Anthropic.

Scale is a multiplier of experience, not a substitute for it. Frit proves you have the experience. The scale will come.
