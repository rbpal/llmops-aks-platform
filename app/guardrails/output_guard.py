"""Output guard (step_05_task02): backstop that redacts stray raw PII before the
authorization-gated detokenize step.
"""
from __future__ import annotations

import re

_SSN = re.compile(r"\b\d{3}-\d{2}-\d{4}\b")
_ACCT = re.compile(r"\bACCT\s*\d{6,}\b", re.IGNORECASE)
_BARE_LONG_NUM = re.compile(r"\b\d{9,}\b")

REDACTED = "[REDACTED]"


def scrub_output(text: str) -> str:
    text = _SSN.sub(REDACTED, text)
    text = _ACCT.sub(REDACTED, text)
    text = _BARE_LONG_NUM.sub(REDACTED, text)
    return text
