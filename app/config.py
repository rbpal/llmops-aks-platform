"""Env-driven settings. TODO(step_01_task01): implement with pydantic-settings."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Region label surfaced in responses so active-active load-balancing tests can see which
    # region replied. Set per region in prod (env REGION=eastus2 / centralus).
    region: str = "local"

    # Defense-in-depth origin lock (option C). When set (to the AFD profile's FDID / resource_guid,
    # from `terraform output afd_fdid`), the app rejects /chat requests whose X-Azure-FDID header
    # doesn't match — so a request that bypasses Front Door straight to the pod/App Gateway is
    # refused even if it cleared the edge. Empty (local/dev/CI) = check disabled. /healthz and
    # /metrics are always exempt (App Gateway backend probe + in-cluster Prometheus carry no FDID).
    expected_fdid: str = ""

    # --- LLM provider routing (TODO step_01_task02 / decision: multi-provider) ---
    llm_provider: str = "azure_openai"          # azure_openai | anthropic

    # Azure OpenAI
    azure_openai_endpoint: str = ""
    azure_openai_api_key: str = ""
    azure_openai_api_version: str = "2024-11-20"
    chat_deployment: str = ""
    embedding_deployment: str = ""

    # Anthropic (Claude) — key added later by operator
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-opus-4-8"

    # --- RAG ---
    vector_store: str = "faiss"                 # faiss | azure_search
    azure_search_endpoint: str = ""
    azure_search_api_key: str = ""
    azure_search_index: str = "corpus"

    # --- PII vault (decision: Key Vault primary) ---
    vault_backend: str = "local"               # local | key_vault
    vault_path: str = "data/vault/vault.json"
    key_vault_uri: str = ""
    is_authorized: bool = False

    # Keyed HMAC tokenization: tokens are HMAC(secret, value), not a bare hash, so
    # they can't be brute-forced from the small SSN keyspace. The secret lives in
    # Key Vault in prod; this env value is the local-dev fallback. Rotating it
    # re-keys all future tokens, so re-ingest after a rotation.
    pii_hmac_secret: str = "dev-only-rotate-me"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
