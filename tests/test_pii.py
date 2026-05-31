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
    tok1 = re.search(r"\[SSN_[0-9a-f]{4}\]", t1).group(0)
    tok2 = re.search(r"\[SSN_[0-9a-f]{4}\]", t2).group(0)
    assert tok1 == tok2
    assert "123-45-6789" not in t1


def test_vault_roundtrip(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    v = vault_mod.LocalVault()
    v.put("[SSN_abcd]", "123-45-6789")
    assert vault_mod.LocalVault().get("[SSN_abcd]") == "123-45-6789"


def test_ingest_strips_raw_pii(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    from app.rag.ingest import ingest
    ingest("data/corpus")
    meta = (tmp_path / "corpus.meta.json").read_text()
    assert "123-45-6789" not in meta
    assert "9876543210" not in meta
    assert "[SSN_" in meta


def test_detokenize_authorization_gated(tmp_path, monkeypatch):
    _isolate(tmp_path, monkeypatch)
    from app.pii.tokenizer import detokenize, tokenize
    tok_text = tokenize("client 123-45-6789")
    monkeypatch.setattr(settings, "is_authorized", False)
    assert "123-45-6789" not in detokenize(tok_text)
    monkeypatch.setattr(settings, "is_authorized", True)
    assert "123-45-6789" in detokenize(tok_text)


def test_token_is_keyed_hmac_not_brute_forceable(tmp_path, monkeypatch):
    """Keyed HMAC: changing the secret changes the token, and the token is NOT the
    plain sha256 an attacker could brute-force from the small SSN keyspace."""
    import hashlib

    _isolate(tmp_path, monkeypatch)
    from app.pii import tokenizer

    ssn = "123-45-6789"
    monkeypatch.setattr(settings, "pii_hmac_secret", "key-AAA")
    t_a = tokenizer._token("SSN", ssn)
    t_a_again = tokenizer._token("SSN", ssn)
    monkeypatch.setattr(settings, "pii_hmac_secret", "key-BBB")
    t_b = tokenizer._token("SSN", ssn)

    assert t_a == t_a_again              # deterministic under a fixed key
    assert t_a != t_b                    # secret actually keys the token
    plain = f"[SSN_{hashlib.sha256(ssn.encode()).hexdigest()[:4]}]"
    assert t_a != plain                  # not a bare hash -> not brute-forceable


def test_inbound_question_pii_tokenized_before_llm(tmp_path, monkeypatch):
    """A user pasting raw PII into the question must not reach the LLM or logs:
    the agent tokenizes the question first."""
    _isolate(tmp_path, monkeypatch)
    import app.agent as agent_mod
    import app.rag.ingest as ing

    ing.ingest("data/corpus")
    seen = {}
    real_client = agent_mod.get_client()

    class SpyClient:
        name = "stub"

        def chat(self, system, user, temperature=0.0):
            seen["user"] = user
            return real_client.chat(system, user, temperature)

        def embed(self, text):
            return real_client.embed(text)

    monkeypatch.setattr(agent_mod, "get_client", lambda: SpyClient())
    agent_mod.answer("What about client 123-45-6789 on the engagement letter?")
    assert "123-45-6789" not in seen["user"]   # raw SSN never reached the LLM
    assert "[SSN_" in seen["user"]             # it was tokenized instead
