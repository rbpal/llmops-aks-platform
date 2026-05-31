"""Deterministic PII (Personally Identifiable Information) tokenizer (step_02_task01).

Detects SSNs and account numbers and replaces them with opaque, deterministic tokens
([SSN_xxxx], [ACCT_xxxx]). Tokens are derived with **keyed HMAC**, not a bare hash:
without the secret, the small SSN keyspace (~10^9) cannot be brute-forced back from a
token. Same value + same key -> same token (so the system still recognizes the same
entity across documents). The token->real mapping is written to the vault so authorized
reads can detokenize.

Two call sites:
  - ingest tokenizes documents BEFORE embedding (PII never enters store/model/logs)
  - the agent tokenizes the inbound QUESTION before retrieval/LLM (so a user pasting
    raw PII doesn't leak it into the model call or request logs), then detokenizes the
    final answer if the caller is authorized.
"""
from __future__ import annotations

import hashlib
import hmac
import re

from app.config import settings
from app.pii.vault import get_vault

SSN_RE = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
ACCT_RE = re.compile(r"\bACCT\s*\d{6,}\b", re.IGNORECASE)
TOKEN_RE = re.compile(r"\[[A-Z]+_[0-9a-f]{4}\]")


def _token(prefix: str, value: str) -> str:
    # Keyed HMAC-SHA256 — not a bare hash — so tokens aren't reversible by brute force.
    digest = hmac.new(
        settings.pii_hmac_secret.encode(), value.encode(), hashlib.sha256
    ).hexdigest()[:4]
    return f"[{prefix}_{digest}]"


def tokenize(text: str) -> str:
    """Replace PII with deterministic keyed tokens; record token->real in the vault."""
    vault = get_vault()

    def _repl(prefix: str):
        def _r(m: re.Match) -> str:
            value = m.group(0)
            tok = _token(prefix, value)
            vault.put(tok, value)
            return tok
        return _r

    text = SSN_RE.sub(_repl("SSN"), text)
    text = ACCT_RE.sub(_repl("ACCT"), text)
    return text


def detokenize(text: str) -> str:
    """Authorization-gated (step_02_task04): swap tokens back to real values only when
    IS_AUTHORIZED; otherwise leave tokens in place."""
    if not settings.is_authorized:
        return text
    vault = get_vault()

    def _r(m: re.Match) -> str:
        tok = m.group(0)
        val = vault.get(tok)
        return val if val is not None else tok

    return TOKEN_RE.sub(_r, text)
