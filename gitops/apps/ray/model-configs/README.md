# frit serve configs , one file per benchmarked variant

Each RayService serves **one** config at a time, injected as `serveConfigV2` in `../kustomization.yaml`.
Every file here is a config we actually benchmarked, so the tree mirrors the benchmark site
(`docs/bench/`): one manifest ↔ one result row. Switch the active config by pointing
`serveConfigV2=model-configs/<file>` in `../kustomization.yaml`.

## Models
- **qwen-05b.yaml** , Qwen2.5-0.5B, fp16 (model 1, the tiny plumbing baseline; head_dim 64, runs on the T4).
- **mistral-7b-*.yaml** , Mistral-7B-Instruct v0.2 (model 2), four precision/tuning variants below.
  All keep `model_id: mistral-7b` + route `/mistral-7b`, so the guidellm sweep recipe is variant-agnostic.

## Mistral-7B variants , benchmarked on a single L4 (Ada sm_89), 256-in / 128-out
| Config file | precision / kernel | single-stream tok/s | TTFT | ITL | KV cache | bench run |
|---|---|---|---|---|---|---|
| `mistral-7b-awq-marlin.yaml` **★ active** | AWQ INT4 + Marlin, CUDA graphs, FLASH_ATTN | **57.3** | 117 ms | 16.7 ms | 15.0 GiB | mistral7b-l4tuned-sweep |
| `mistral-7b-awq-int4.yaml` | AWQ INT4, plain kernel, eager, TORCH_SDPA (Turing-safe baseline) | 34.5 | 269 ms | 27.2 ms | 15.5 GiB | mistral7b-awq-sweep |
| `mistral-7b-fp8.yaml` | FP8 dynamic (Ada fp8 tensor cores) | 29.8 | 118 ms | 32.9 ms | 11.9 GiB | mistral7b-fp8-sweep |
| `mistral-7b-fp16.yaml` | FP16 unquantized (quality baseline) | 17.5 | 218 ms | 56.0 ms | 5.5 GiB | mistral7b-fp16-sweep |

## What the numbers say
- **Decode is memory-bandwidth-bound.** ITL tracks weight-bytes-moved-per-token: int4 (~3.5 GB) 16.7 ms ->
  fp8 (~7 GB) 32.9 ms (~2x) -> fp16 (~14 GB) 56 ms (~4x). Quantization is a **decode-latency + concurrency**
  (KV headroom) win on a bandwidth-limited card, not just a memory-footprint win.
- **Config, not just precision.** The awq-int4 -> awq-marlin change (Marlin kernel + CUDA graphs + native
  attention, *same weights, same precision*) alone bought **+66% throughput and halved TTFT** , the Turing-era
  defaults were crippling the Ada card.
- **FP8 is the L4's edge:** 2x compression with better accuracy than INT4, using Ada fp8 tensor cores an
  A100 doesn't have. The quality-vs-speed sweet spot.
