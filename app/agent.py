"""Agent graph: input_guard -> domain_guard -> retrieve -> assemble -> generate ->
output_guard -> detokenize, with per-request telemetry (steps 01/02/05/06).
"""
from __future__ import annotations

import logging
import time

from app.guardrails.input_guard import check_input
from app.guardrails.output_guard import scrub_output
from app.llm.client import get_client
from app.observability import metrics
from app.pii.tokenizer import detokenize, tokenize
from app.registry import loader
from app.rag.retriever import retrieve

logger = logging.getLogger("llmops.agent")

REFUSAL = "I can only help with accounting and tax questions."
BLOCKED = "Your request was blocked by the input guard."

_OFF_TOPIC = ("weather", "sports", "recipe", "movie", "stock price", "lottery")


def domain_guard(question: str) -> bool:
    q = question.lower()
    return not any(term in q for term in _OFF_TOPIC)


def _format_context(chunks: list[dict]) -> str:
    return "\n".join(f"[source: {c['source']}] {c['content']}" for c in chunks)


def answer(question: str, k: int = 4) -> dict:
    ok, reason = check_input(question)
    if not ok:
        logger.warning("input_guard blocked: %s", reason)
        return {"answer": BLOCKED, "sources": [], "prompt": None, "provider": None}

    if not domain_guard(question):
        return {"answer": REFUSAL, "sources": [], "prompt": None, "provider": None}

    # Tokenize PII the user may have pasted into the question BEFORE it reaches
    # retrieval, the LLM, or request logs. Same keyed tokens as ingestion, so a
    # tokenized SSN in the question matches the tokenized SSN stored in the corpus.
    question = tokenize(question)

    chunks = retrieve(question, k=k)
    context = _format_context(chunks)
    prompt = loader.load("answer_generation")
    audit = f"{prompt.name} v{prompt.version} @{prompt.git_sha}"
    logger.info("prompt %s", audit)

    client = get_client()
    system = "You are an accounting/tax assistant. Answer only from the context."
    user_msg = prompt.template.format(context=context, question=question)

    t0 = time.perf_counter()
    try:
        raw = client.chat(system=system, user=user_msg, temperature=prompt.temperature)
    except Exception:
        metrics.failures.labels(client.name).inc()
        logger.exception("LLM call failed")
        raise
    elapsed = time.perf_counter() - t0

    metrics.record(
        provider=client.name,
        model=prompt.model or client.name,
        n_in=metrics.count_tokens(system + user_msg),
        n_out=metrics.count_tokens(raw),
        latency_s=elapsed,
    )

    raw = scrub_output(raw)
    text = detokenize(raw)
    sources = list(dict.fromkeys(c["source"] for c in chunks))
    return {"answer": text, "sources": sources, "prompt": audit, "provider": client.name}
