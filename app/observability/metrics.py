"""Prometheus metrics: tokens, cost, latency, failures — labeled BY PROVIDER
(multi-provider decision). TODO(step_06_task01/02)."""
from prometheus_client import Counter, Histogram

tokens_in = Counter("llm_tokens_in_total", "Input tokens", ["provider", "model"])
tokens_out = Counter("llm_tokens_out_total", "Output tokens", ["provider", "model"])
cost_usd = Counter("llm_cost_usd_total", "Estimated cost USD", ["provider", "model"])
failures = Counter("llm_failures_total", "Failed requests", ["provider"])
latency = Histogram("chat_latency_seconds", "End-to-end /chat latency")
# TODO(step_06_task02): cost calc via tiktoken + price table
