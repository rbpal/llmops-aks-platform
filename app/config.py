"""Env-driven settings. TODO(step_01_task01): implement with pydantic-settings."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- LLM provider routing (TODO step_01_task02 / decision: multi-provider) ---
    llm_provider: str = "azure_openai"          # azure_openai | anthropic
    use_stub_llm: bool = True

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


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
