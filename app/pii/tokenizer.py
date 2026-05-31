"""Deterministic PII tokenizer (step_02_task01).

Detects SSNs and account numbers and replaces them with opaque, deterministic
tokens ([SSN_xxxx], [ACCT_xxxx]) — same value always yields the same token. The
token->real mapping is written to the vault so authorized reads can detokenize.
"""
from __future__ import annotations

import hashlib
import re

from app.config import settings
from app.pii.vault import get_vault

SSN_RE = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
ACCT_RE = re.compile(r"\bACCT\s*\d{6,}\b", re.IGNORECASE)
TOKEN_RE = re.compile(r"\[[A-Z]+_[0-9a-f]{4}\]")


def _token(prefix: str, value: str) -> str:
    h = hashlib.sha256(value.encode()).hexdigest()[:4]
    return f"[{prefix}_{h}]"


def tokenize(text: str) -> str:
    """Replace PII with deterministic tokens; record token->real in the vault."""
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
    """Authorization-gated (step_02_task04): swap tokens back to real values only
    when IS_AUTHORIZED; otherwise leave tokens in place."""
    if not settings.is_authorized:
        return text
    vault = get_vault()

    def _r(m: re.Match) -> str:
        tok = m.group(0)
        val = vault.get(tok)
        return val if val is not None else tok

    return TOKEN_RE.sub(_r, text)
