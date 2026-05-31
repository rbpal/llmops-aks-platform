"""Ingest: read corpus -> tokenize PII -> chunk -> embed -> upsert
(step_01_task05 + step_02_task03).

PII is tokenized BEFORE embedding, so raw SSNs/account numbers never reach the
embeddings, the vector store, or the logs.
"""
from __future__ import annotations

from pathlib import Path

from app.llm.client import get_client
from app.pii.tokenizer import tokenize
from app.rag.store import get_store

CORPUS_DIR = Path("data/corpus")


def _chunk(text: str, words_per_chunk: int = 120) -> list[str]:
    words = text.split()
    return [" ".join(words[i:i + words_per_chunk])
            for i in range(0, len(words), words_per_chunk)] or [text]


def ingest(corpus_dir: str | Path = CORPUS_DIR) -> int:
    client = get_client()
    store = get_store()
    records: list[dict] = []
    for md in sorted(Path(corpus_dir).glob("*.md")):
        text = tokenize(md.read_text())   # PII out before anything else
        for j, chunk in enumerate(_chunk(text)):
            records.append({
                "id": f"{md.stem}-{j}",
                "content": chunk,
                "source": md.name,
                "content_vector": client.embed(chunk),
            })
    if not records:
        return 0
    store.upsert(records)
    return len(records)


if __name__ == "__main__":
    n = ingest()
    print(f"ingested {n} chunks")
