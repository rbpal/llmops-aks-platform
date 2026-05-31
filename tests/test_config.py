from app.config import settings


def test_settings_load():
    # defaults: stub on, faiss store, local vault
    assert settings.use_stub_llm is True
    assert settings.vector_store in ("faiss", "azure_search")
    assert settings.llm_provider in ("azure_openai", "anthropic")
