# frit concepts primer , the inference-serving vocabulary

Plain definitions for every term the AISPE lab uses. Read once for the mental model; each term is re-explained in context when we build it.

The request path in frit: **Open WebUI → LiteLLM → vLLM → GPU**. Everything below is about the last two hops.

## The one mental model everything hangs on: prefill vs decode
An LLM answers in two phases:
- **Prefill** , it reads your whole prompt at once and builds internal state. Compute-heavy, parallel, fast per token. Determines **TTFT** (time to first token).
- **Decode** , it then generates the answer **one token at a time**, each new token attending to all previous ones. Memory-bandwidth-heavy, sequential. Determines **TPOT** (time per output token).
Prefill is a sprint; decode is a slow drip. Almost every optimization targets one phase or the other.

## Serving mechanics
- **KV cache** , during decode, the model would otherwise re-compute attention over the whole sequence every token. Instead it caches each token's Key/Value vectors and reuses them. This cache **grows with every token and every concurrent request**, and it lives in GPU memory , on a 16 GB T4 it's the thing that fills up and forces limits. Size ≈ `2 × layers × kv_heads × head_dim × bytes` per token.
- **PagedAttention** , vLLM's trick: store the KV cache in fixed-size **pages** (like OS virtual memory) instead of one big contiguous block. Kills fragmentation, so you can pack many more concurrent requests before running out of memory. On by default; don't fight it.
- **Continuous (in-flight) batching** , instead of waiting to collect a fixed batch, vLLM admits/evicts requests **every single decode step**. A new request joins mid-flight; a finished one leaves immediately. Keeps the GPU busy at high load *and* responsive at low load. The #1 throughput lever on one GPU.
- **Chunked prefill** , a long prompt's prefill is sliced into chunks, and decode steps for *other* users are slipped into the gaps , so one big prompt doesn't freeze everyone else's token stream. Critical on a single GPU.
- **Prefix caching** , if two requests share a prefix (same system prompt, multi-turn history, the same RAG document), reuse the cached KV instead of re-computing prefill. Near-linear speedup when prefixes repeat. `enable_prefix_caching=True`.

## Precision / quantization (the T4's real levers)
- **FP16 / BF16 / FP8** , number formats for weights/activations. Smaller = less memory + faster, but lossier. **The T4 (Turing, 2019) does FP16 and INT8 only** , no FP8, weak BF16. So the book's fp8 path is off-limits; FP16 is our activation format.
- **INT8 / INT4 weight quantization (AWQ, GPTQ)** , shrink the model's weights to 8- or 4-bit. **INT4** makes a 7B model ~3.5 GB (from ~14 GB FP16), freeing room for KV cache. **AWQ** and **GPTQ** are two popular INT4 methods with ready-made checkpoints on HuggingFace , this is how a 7-9B model fits a 16 GB T4.
- **KV-cache quantization** , store the KV cache itself in INT8 (or INT4 under pressure) instead of FP16, roughly halving its footprint so you fit more concurrent contexts. Our fp8-KV substitute on Turing.

## The metrics (what "good" means)
- **TTFT (time to first token)** , how long until the answer starts streaming. Prefill latency. The number users *feel* first.
- **TPOT / ITL (time per output token / inter-token latency)** , the pace of streaming after that. Decode latency. Should beat human read speed (~4-13 tok/s).
- **Throughput** , total tokens/sec or requests/sec across all users. What batching maximizes.
- **Goodput** , the headline SRE metric: **useful work completed per second**, discounting stalls, failures, retries, idle compute. `goodput = achieved / peak_theoretical`. The point: `nvidia-smi` can show "100% GPU" while goodput is 30% , exposing that gap is the whole game. Always report **percentiles** (p50/p95/p99), never just averages , the tail is what hurts.

## The infra pieces
- **vLLM** , the inference *engine*: loads the model, runs prefill/decode, owns PagedAttention + continuous batching + the KV cache. This is where the GPU work happens.
- **Ray Serve** , a *serving framework* on top: lets you run **multiple models** (and multiple replicas) on the cluster, share one GPU fractionally between them, and expose them behind one endpoint. It's how frit serves several models on a single card (M-A).
- **LiteLLM** , the *gateway*: one OpenAI-compatible API in front of many models, with keys, routing, budgets, and A/B weighting. frit already runs it.
- **DCGM** , NVIDIA's GPU telemetry: utilization, memory, temperature, power, throttle reasons, ECC errors. Already scraped into frit's Prometheus. The source of GPU-health SLOs.

## Advanced (later milestones)
- **Speculative decoding** , a tiny fast "draft" model guesses several tokens ahead, the big model verifies them in one batch. ~1.5-2.5x speedup when it works; needs a matching-vocab draft model and spare memory (tight on 16 GB).
- **CPU / KV offload** , when GPU memory fills, page older KV blocks to host RAM and fetch them back on demand (`cpu_offload_gb`). ~5-10% penalty if overlapped well; lets you run bigger contexts than 16 GB alone allows.

---
Rule of the lab (from the book): **baseline → profile → change one thing → re-measure**, and never claim an optimization worked without a before/after number.
