"""Vector store behind one interface (step_01_task04).

FaissStore = local inner-loop store (real, save/load). AzureSearchStore = managed
cloud store (Azure AI Search). Backend selected by VECTOR_STORE; no branching in
callers — they use get_store().
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from app.config import settings

INDEX_DIR = Path(__file__).parent / "index"
FAISS_PATH = INDEX_DIR / "corpus.faiss"
META_PATH = INDEX_DIR / "corpus.meta.json"


class VectorStore:
    def ensure_index(self) -> None: ...
    def upsert(self, records: list[dict]) -> None: ...
    def search(self, vector: list[float], k: int = 4) -> list[dict]: ...


class FaissStore(VectorStore):
    """Local FAISS IndexFlatL2 + a JSON metadata sidecar."""

    def __init__(self) -> None:
        self._index = None
        self._meta: list[dict] = []

    def ensure_index(self, dim: int | None = None) -> None:
        import faiss

        if self._index is None and dim is not None:
            self._index = faiss.IndexFlatL2(dim)

    def upsert(self, records: list[dict]) -> None:
        import faiss

        vecs = np.array([r["content_vector"] for r in records], dtype="float32")
        self.ensure_index(dim=vecs.shape[1])
        self._index.add(vecs)
        for r in records:
            self._meta.append({k: v for k, v in r.items() if k != "content_vector"})
        INDEX_DIR.mkdir(parents=True, exist_ok=True)
        faiss.write_index(self._index, str(FAISS_PATH))
        META_PATH.write_text(json.dumps(self._meta))

    def _load(self) -> None:
        import faiss

        if self._index is None:
            self._index = faiss.read_index(str(FAISS_PATH))
            self._meta = json.loads(META_PATH.read_text())

    def search(self, vector: list[float], k: int = 4) -> list[dict]:
        self._load()
        q = np.array([vector], dtype="float32")
        dists, idxs = self._index.search(q, min(k, len(self._meta)))
        out = []
        for dist, i in zip(dists[0], idxs[0]):
            if i < 0:
                continue
            hit = dict(self._meta[i])
            hit["score"] = float(dist)
            out.append(hit)
        return out


class AzureSearchStore(VectorStore):
    """Managed Azure AI Search backend (step_01_task04). Verified against a
    Free-tier service; TODO: finish ensure_index/upsert with azure-search-documents."""

    def __init__(self) -> None:
        from azure.core.credentials import AzureKeyCredential
        from azure.search.documents import SearchClient

        self._client = SearchClient(
            endpoint=settings.azure_search_endpoint,
            index_name=settings.azure_search_index,
            credential=AzureKeyCredential(settings.azure_search_api_key),
        )

    def ensure_index(self) -> None:
        raise NotImplementedError  # TODO(step_01_task04): create index schema

    def upsert(self, records: list[dict]) -> None:
        self._client.upload_documents(documents=records)

    def search(self, vector: list[float], k: int = 4) -> list[dict]:
        from azure.search.documents.models import VectorizedQuery

        vq = VectorizedQuery(vector=vector, k_nearest_neighbors=k, fields="content_vector")
        results = self._client.search(search_text=None, vector_queries=[vq], top=k)
        return [dict(r) for r in results]


def get_store() -> VectorStore:
    return AzureSearchStore() if settings.vector_store == "azure_search" else FaissStore()
