"""Input guard (step_05_task01): prompt-injection heuristics.

Returns (ok, reason). ok=False means block before retrieval or the model.
"""
from __future__ import annotations

import re

_INJECTION_PATTERNS = [
    r"ignore (all |the )?(previous|above|prior) (instructions|prompts?)",
    r"disregard (all |the )?(previous|above|prior)",
    r"forget (your|all) (instructions|rules)",
    r"you are now\b",
    r"reveal (your|the) (system )?(prompt|instructions)",
    r"print (your|the) (system )?(prompt|instructions)",
    r"developer mode|jailbreak|dan mode",
    r"dump (all )?(other )?(clients?|customer).{0,20}(data|records|pii)",
]
_RE = re.compile("|".join(_INJECTION_PATTERNS), re.IGNORECASE)


def check_input(text: str) -> tuple[bool, str]:
    m = _RE.search(text or "")
    if m:
        return False, f"prompt-injection pattern: {m.group(0)!r}"
    return True, ""
