import re

import app.pii.vault as vault_mod
import app.rag.store as store_mod
from app.config import settings


def _isolate(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "vault_path", str(tmp_path / "vault.json"))
    monkeypatch.setattr(store_mod, "INDEX_DIR", tmp_path)
    monkeypatch.setattr(store_mod, "FAISS_PATH", tmp_path / "corpus.faiss")
    monkeypatch.setattr(store_mod, "META_PATH", tmp_path / "corpus.meta.json")


def test_tokenize_deterministic(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    from app.pii.tokenizer import tokenize
    t1 = tokenize("SSN 123-45-6789")
    t2 = tokenize("again 123-45-6789")
    # same value -> same token, and no raw SSN remains
    tok1 = re.search(r"\[SSN_[0-9a-f]{4}\]", t1).group(0)
    tok2 = re.search(r"\[SSN_[0-9a-f]{4}\]", t2).group(0)
    assert tok1 == tok2
    assert "123-45-6789" not in t1


def test_vault_roundtrip(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    v = vault_mod.LocalVault()
    v.put("[SSN_abcd]", "123-45-6789")
    assert vault_mod.LocalVault().get("[SSN_abcd]") == "123-45-6789"  # persisted + encrypted


def test_ingest_strips_raw_pii(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    from app.rag.ingest import ingest
    ingest("data/corpus")
    meta = (tmp_path / "corpus.meta.json").read_text()
    # raw SSN and raw account number must NOT be in the stored chunks
    assert "123-45-6789" not in meta
    assert "9876543210" not in meta
    assert "[SSN_" in meta  # the token is there instead


def test_detokenize_authorization_gated(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    from app.pii.tokenizer import detokenize, tokenize
    tok_text = tokenize("client 123-45-6789")
    # unauthorized -> tokens stay
    monkeypatch.setattr(settings, "is_authorized", False)
    assert "123-45-6789" not in detokenize(tok_text)
    # authorized -> real value restored
    monkeypatch.setattr(settings, "is_authorized", True)
    assert "123-45-6789" in detokenize(tok_text)
