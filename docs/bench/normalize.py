#!/usr/bin/env python3
"""
Normalize guidellm result JSONs into a flat data.json the Benchmarks page reads.

Why: guidellm's raw report is large, deeply nested, and version-specific. The
static page should not parse that. This distills each benchmark strategy into one
compact row (model / precision / gpu / profile + the headline metrics with
percentiles), so the UI stays trivial and version changes only touch this file.

Input : docs/bench/results/*.json   (raw guidellm reports, the source of truth)
Output: docs/bench/data.json        (list of rows, what the page fetches)

Run: python3 docs/bench/normalize.py
"""
from __future__ import annotations

import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
RESULTS = HERE / "results"
OUT = HERE / "data.json"

PRECISIONS = {"fp16", "fp8", "bf16", "fp32", "int8", "int4", "awq", "gptq"}
PROFILE_ALIASES = {"sync": "synchronous", "tput": "throughput"}


def stat(metric: dict, key: str, status: str = "successful"):
    """One summary stat (mean/median/...) for a metric+status, or None."""
    try:
        return round(metric[status][key], 2)
    except (KeyError, TypeError):
        return None


def pcts(metric: dict, status: str = "successful"):
    """The percentile bundle we care about for a metric, rounded."""
    try:
        p = metric[status]["percentiles"]
    except (KeyError, TypeError):
        return {}
    return {k: round(p[k], 2) for k in ("p50", "p90", "p95", "p99") if k in p}


def latency(metrics: dict, name: str):
    """median + mean + key percentiles for a latency-style metric."""
    m = metrics.get(name)
    if not m:
        return None
    return {"median": stat(m, "median"), "mean": stat(m, "mean"), **pcts(m)}


def meta_from_filename(stem: str):
    """`qwen05b-fp16-sync` -> model hint / precision / profile hint."""
    parts = stem.split("-")
    precision = next((p for p in parts if p in PRECISIONS), "unknown")
    profile_hint = parts[-1] if parts else ""
    return precision, PROFILE_ALIASES.get(profile_hint, profile_hint)


def row_for(report: dict, benches: list, report_meta: dict, labels: dict, fname: str):
    # One row per FILE (run). A sweep file holds many benchmark strategies; we
    # surface it as a single catalog row (the report page reads the raw json and
    # draws the vs-load curve across all strategies). Headline metrics come from
    # the first strategy (the synchronous baseline) purely so data.json stays
    # well-formed; the catalog does not display them.
    stem = pathlib.Path(fname).stem
    precision_fn, profile_fn = meta_from_filename(stem)
    is_sweep = len(benches) > 1
    bench = benches[0]
    cfg = bench.get("config", {})
    metrics = bench.get("metrics", {})

    return {
        "run": stem,
        "model": cfg.get("backend", {}).get("model") or labels.get("model"),
        # gpu/precision aren't in guidellm's json; prefer --label, fall back to filename/default
        "gpu": labels.get("gpu", "T4"),
        "precision": labels.get("precision", precision_fn),
        "profile": profile_fn or cfg.get("profile", {}).get("kind"),
        "strategies": len(benches),
        # sweep spans many concurrency levels; a single number is misleading, so leave it blank
        "max_concurrency": None if is_sweep else cfg.get("strategy", {}).get("max_concurrency"),
        "duration_s": round(bench.get("duration", 0), 1),
        "requests_ok": stat(metrics.get("time_to_first_token_ms", {}), "count") or 0,
        "requests_err": stat(metrics.get("time_to_first_token_ms", {}), "count", "errored") or 0,
        "ttft_ms": latency(metrics, "time_to_first_token_ms"),
        "itl_ms": latency(metrics, "inter_token_latency_ms"),
        "tpot_ms": latency(metrics, "time_per_output_token_ms"),
        "req_latency_s": latency(metrics, "request_latency"),
        "throughput": {
            "req_per_s": stat(metrics.get("requests_per_second", {}), "mean"),
            "output_tok_per_s": stat(metrics.get("output_tokens_per_second", {}), "mean"),
            "total_tok_per_s": stat(metrics.get("tokens_per_second", {}), "mean"),
        },
        "tokens": {
            "prompt_median": stat(metrics.get("prompt_token_count", {}), "median"),
            "output_median": stat(metrics.get("output_token_count", {}), "median"),
        },
        "guidellm_version": report_meta.get("guidellm_version"),
        "raw": f"results/{fname}",  # the report page (report.html?run=) reads this raw json directly
    }


def main():
    rows = []
    for path in sorted(RESULTS.glob("*.json")):
        report = json.loads(path.read_text())
        report_meta = report.get("metadata", {})
        labels = report_meta.get("labels") or {}
        benches = report.get("benchmarks", [])
        if not benches:
            continue
        rows.append(row_for(report, benches, report_meta, labels, path.name))
    OUT.write_text(json.dumps(rows, indent=2))
    print(f"wrote {OUT.relative_to(HERE.parent)}  ({len(rows)} row(s))")


if __name__ == "__main__":
    main()
