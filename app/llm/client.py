"""LLM client with a provider router seam.

TODO(step_01_task02): implement Azure OpenAI + Anthropic backends behind one
interface, honoring USE_STUB_LLM. Decision: multi-provider (see project memory).
"""
from __future__ import annotations

from app.config import settings


class LLMClient:
    """Common chat + embeddings interface across providers."""

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        raise NotImplementedError

    def embed(self, text: str) -> list[float]:
        raise NotImplementedError


class StubLLM(LLMClient):
    """No-network canned responses for the inner loop / CI."""

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        return "[stub answer] [source: stub]"

    def embed(self, text: str) -> list[float]:
        return [0.0] * 1536


class AzureOpenAIClient(LLMClient):
    pass  # TODO(step_01_task02): AzureOpenAI chat + embeddings


class AnthropicClient(LLMClient):
    pass  # TODO(step_01_task02): Anthropic chat (embeddings still via Azure)


def get_client() -> LLMClient:
    """Select provider by config. TODO(step_01_task02)."""
    if settings.use_stub_llm:
        return StubLLM()
    if settings.llm_provider == "anthropic":
        return AnthropicClient()
    return AzureOpenAIClient()
