import app.rag.store as store_mod
from app.rag.ingest import ingest
from app.rag.retriever import retrieve


def test_ingest_then_retrieve(tmp_path, monkeypatch):
    # isolate the FAISS index to a temp dir
    monkeypatch.setattr(store_mod, "INDEX_DIR", tmp_path)
    monkeypatch.setattr(store_mod, "FAISS_PATH", tmp_path / "corpus.faiss")
    monkeypatch.setattr(store_mod, "META_PATH", tmp_path / "corpus.meta.json")

    n = ingest("data/corpus")
    assert n > 0

    hits = retrieve("capitalization threshold for depreciation", k=3)
    assert hits
    # the depreciation policy doc should be the top grounded source
    assert any("depreciation" in h["source"] for h in hits)
