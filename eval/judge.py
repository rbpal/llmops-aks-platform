"""LLM-as-judge (step_04_task01). Real LLM via eval_judge prompt; deterministic
heuristic in stub mode so the gate runs end to end offline.
"""
from __future__ import annotations

import json
import re

from app.config import settings
from app.llm.client import get_client
from app.registry import loader


def _significant(text: str) -> set[str]:
    return {w for w in re.findall(r"[a-z0-9$%]+", text.lower()) if len(w) > 3}


def _heuristic(actual: str, expected: str) -> dict:
    exp = _significant(expected)
    act = _significant(actual)
    overlap = len(exp & act) / (len(exp) or 1)
    return {"correctness": round(min(1.0, overlap / 0.5), 3),
            "grounded": 1.0 if actual.strip() else 0.0}


def judge(question: str, actual: str, expected: str, context: str) -> dict:
    if settings.use_stub_llm:
        return _heuristic(actual, expected)
    prompt = loader.load("eval_judge")
    raw = get_client().chat(
        system="You are a strict grader. Output only JSON.",
        user=prompt.template.format(
            question=question, context=context, expected=expected, actual=actual),
        temperature=0.0,
    )
    try:
        return json.loads(re.search(r"\{.*\}", raw, re.S).group(0))
    except Exception:
        return {"correctness": 0.0, "grounded": 0.0}
