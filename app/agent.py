"""Agent graph (step_01_task06): domain_guard -> retrieve -> assemble -> generate.

On read, detokenize is authorization-gated (step_02_task04): authorized callers
get real PII values restored; everyone else keeps the opaque tokens.
"""
from __future__ import annotations

from app.llm.client import get_client
from app.pii.tokenizer import detokenize
from app.registry import loader
from app.rag.retriever import retrieve

REFUSAL = "I can only help with accounting and tax questions."

# Minimal domain guard for the spine; full guardrails arrive in step_05.
_OFF_TOPIC = ("weather", "sports", "recipe", "movie", "stock price", "lottery")


def domain_guard(question: str) -> bool:
    q = question.lower()
    return not any(term in q for term in _OFF_TOPIC)


def _format_context(chunks: list[dict]) -> str:
    return "\n".join(f"[source: {c['source']}] {c['content']}" for c in chunks)


def answer(question: str, k: int = 4) -> dict:
    if not domain_guard(question):
        return {"answer": REFUSAL, "sources": [], "prompt": None, "provider": None}

    chunks = retrieve(question, k=k)
    context = _format_context(chunks)
    prompt = loader.load("answer_generation")
    user_msg = prompt.template.format(context=context, question=question)

    client = get_client()
    text = client.chat(
        system="You are an accounting/tax assistant. Answer only from the context.",
        user=user_msg,
        temperature=prompt.temperature,
    )
    text = detokenize(text)   # authorization-gated; no-op unless IS_AUTHORIZED
    sources = list(dict.fromkeys(c["source"] for c in chunks))
    return {
        "answer": text,
        "sources": sources,
        "prompt": f"{prompt.name} v{prompt.version} @{prompt.git_sha}",
        "provider": client.name,
    }
