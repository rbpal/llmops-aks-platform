from app.config import settings


def test_settings_load():
    # defaults: faiss store, local vault
    assert settings.vector_store in ("faiss", "azure_search")
    assert settings.llm_provider in ("azure_openai", "anthropic")
