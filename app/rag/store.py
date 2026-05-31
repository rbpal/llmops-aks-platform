"""Vector store behind one interface: FAISS (local) + Azure AI Search (cloud).

TODO(step_01_task04): finish FaissStore save/load; verify AzureSearchStore.
"""
from __future__ import annotations

from app.config import settings


class VectorStore:
    def ensure_index(self) -> None: ...
    def upsert(self, records: list[dict]) -> None: ...
    def search(self, vector: list[float], k: int = 4) -> list[dict]: ...


class FaissStore(VectorStore):
    pass  # TODO(step_01_task04): local FAISS index save/load


class AzureSearchStore(VectorStore):
    pass  # TODO(step_01_task04): azure-search-documents backend


def get_store() -> VectorStore:
    return AzureSearchStore() if settings.vector_store == "azure_search" else FaissStore()
