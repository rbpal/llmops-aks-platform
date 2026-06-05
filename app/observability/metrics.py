"""Prometheus metrics + cost calc (step_06_task01/02).

Counters labeled by provider/model (multi-provider + FinOps). Exposed at /metrics;
scraped by Azure Monitor Managed Prometheus on AKS unchanged (step_06_task03).
"""
from __future__ import annotations

from prometheus_client import Counter, Histogram

tokens_in = Counter("llm_tokens_in_total", "Input tokens", ["provider", "model"])
tokens_out = Counter("llm_tokens_out_total", "Output tokens", ["provider", "model"])
cost_usd = Counter("llm_cost_usd_total", "Estimated cost (USD)", ["provider", "model"])
requests_total = Counter("chat_requests_total", "Chat requests", ["provider", "status"])
failures = Counter("llm_failures_total", "Failed LLM calls", ["provider"])
latency = Histogram("chat_latency_seconds", "End-to-end /chat latency (s)")

PRICE_PER_1K = {
    "gpt-4.1-mini": (0.0004, 0.0016),
    "gpt-4o-mini": (0.00015, 0.00060),
    "text-embedding-3-small": (0.00002, 0.0),
    "claude-opus-4-8": (0.015, 0.075),
}

_enc = None


def _encoding():
    global _enc
    if _enc is None:
        import tiktoken
        try:
            _enc = tiktoken.get_encoding("o200k_base")
        except Exception:
            _enc = tiktoken.get_encoding("cl100k_base")
    return _enc


def count_tokens(text: str) -> int:
    return len(_encoding().encode(text or ""))


def record(provider: str, model: str, n_in: int, n_out: int, latency_s: float) -> None:
    tokens_in.labels(provider, model).inc(n_in)
    tokens_out.labels(provider, model).inc(n_out)
    p_in, p_out = PRICE_PER_1K.get(model, (0.0, 0.0))
    cost_usd.labels(provider, model).inc(n_in / 1000 * p_in + n_out / 1000 * p_out)
    latency.observe(latency_s)
    requests_total.labels(provider, "ok").inc()
