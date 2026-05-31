"""LLM client with a provider router seam (step_01_task02).

Provider selected by LLM_PROVIDER (azure_openai | anthropic) behind one
chat/embeddings interface. USE_STUB_LLM=true returns deterministic offline
responses (no network) — the stub embedding is a hashing bag-of-words vector so
RAG retrieval still works locally. Embeddings always go to Azure (decision:
Anthropic has none). Anthropic key is added later — its SDK is imported lazily.
"""
from __future__ import annotations

import hashlib
import math

from app.config import settings

STUB_DIM = 256


def _stub_embed(text: str, dim: int = STUB_DIM) -> list[float]:
    """Deterministic hashing embedding: same text -> same vector, similar text
    -> similar vector. Lets FAISS retrieval work offline without an API."""
    vec = [0.0] * dim
    for tok in text.lower().split():
        h = int(hashlib.md5(tok.encode()).hexdigest(), 16)
        vec[h % dim] += 1.0
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


class LLMClient:
    """Common chat + embeddings interface across providers."""

    name = "base"

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        raise NotImplementedError

    def embed(self, text: str) -> list[float]:
        raise NotImplementedError


class StubLLM(LLMClient):
    name = "stub"

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        # Echo the grounded context back so the offline answer looks real.
        context = user
        if "Context:" in user:
            context = user.split("Context:", 1)[1]
        if "Question:" in context:
            context = context.split("Question:", 1)[0]
        snippet = " ".join(context.split())[:240].strip()
        if not snippet:
            return "I don't have that information."
        return f"Based on the firm's documents: {snippet}"

    def embed(self, text: str) -> list[float]:
        return _stub_embed(text)


class AzureOpenAIClient(LLMClient):
    name = "azure_openai"

    def __init__(self) -> None:
        from openai import AzureOpenAI

        self._c = AzureOpenAI(
            azure_endpoint=settings.azure_openai_endpoint,
            api_key=settings.azure_openai_api_key,
            api_version=settings.azure_openai_api_version,
        )

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        r = self._c.chat.completions.create(
            model=settings.chat_deployment,
            messages=[{"role": "system", "content": system},
                      {"role": "user", "content": user}],
            temperature=temperature,
        )
        return r.choices[0].message.content or ""

    def embed(self, text: str) -> list[float]:
        r = self._c.embeddings.create(model=settings.embedding_deployment, input=text)
        return r.data[0].embedding


class AnthropicClient(LLMClient):
    name = "anthropic"

    def __init__(self) -> None:
        import anthropic  # lazy: package/key added later

        self._c = anthropic.Anthropic(api_key=settings.anthropic_api_key)

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        m = self._c.messages.create(
            model=settings.anthropic_model,
            max_tokens=1024,
            system=system,
            messages=[{"role": "user", "content": user}],
            temperature=temperature,
        )
        return m.content[0].text

    def embed(self, text: str) -> list[float]:
        # Embeddings stay on Azure (decision).
        return AzureOpenAIClient().embed(text)


def get_client() -> LLMClient:
    if settings.use_stub_llm:
        return StubLLM()
    if settings.llm_provider == "anthropic":
        return AnthropicClient()
    return AzureOpenAIClient()
