"""LLM client with a provider router seam (step_01_task02).

Provider selected by LLM_PROVIDER (azure_openai | anthropic) behind one
chat/embeddings interface. Embeddings always go to Azure (decision: Anthropic
has none). Anthropic key is added later — its SDK is imported lazily.
"""
from __future__ import annotations

from app.config import settings


class LLMClient:
    """Common chat + embeddings interface across providers."""

    name = "base"

    def chat(self, system: str, user: str, temperature: float = 0.0) -> str:
        raise NotImplementedError

    def embed(self, text: str) -> list[float]:
        raise NotImplementedError


class AzureOpenAIClient(LLMClient):
    name = "azure_openai"

    def __init__(self) -> None:
        from openai import AzureOpenAI

        # Prefer AAD (DefaultAzureCredential) — works with `az login` locally and AKS
        # workload identity in prod, so no long-lived key lives in env/image/pod. Falls
        # back to an API key only if one is set (and the resource permits key auth).
        if settings.azure_openai_api_key:
            self._c = AzureOpenAI(
                azure_endpoint=settings.azure_openai_endpoint,
                api_key=settings.azure_openai_api_key,
                api_version=settings.azure_openai_api_version,
            )
        else:
            import os

            from azure.identity import DefaultAzureCredential, get_bearer_token_provider

            # Locally (no workload-identity federated token), skip the managed-identity IMDS
            # probe — it stalls ~75s on a laptop before falling back to `az login`. In AKS,
            # AZURE_FEDERATED_TOKEN_FILE is set and WorkloadIdentityCredential resolves first.
            exclude_mi = not os.environ.get("AZURE_FEDERATED_TOKEN_FILE")
            token_provider = get_bearer_token_provider(
                DefaultAzureCredential(exclude_managed_identity_credential=exclude_mi),
                "https://cognitiveservices.azure.com/.default",
            )
            self._c = AzureOpenAI(
                azure_endpoint=settings.azure_openai_endpoint,
                azure_ad_token_provider=token_provider,
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
    if settings.llm_provider == "anthropic":
        return AnthropicClient()
    return AzureOpenAIClient()
