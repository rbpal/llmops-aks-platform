"""LLM-as-judge (step_04_task01). Grades answers with the real LLM via the
eval_judge prompt.
"""
from __future__ import annotations

import json
import re

from app.llm.client import get_client
from app.registry import loader


def judge(question: str, actual: str, expected: str, context: str) -> dict:
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
