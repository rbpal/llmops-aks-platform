"""Prompt registry loader (step_01_task03).

Loads a versioned prompt YAML by name, exposes template/model/temperature, and
records the current git SHA so every answer is traceable (git history = audit trail).
"""
from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path

import yaml

PROMPTS_DIR = Path(__file__).parent / "prompts"


@dataclass
class Prompt:
    name: str
    version: int
    template: str
    model: str
    temperature: float
    git_sha: str


def _git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=Path(__file__).resolve().parent,
            stderr=subprocess.DEVNULL,
        ).decode().strip()
    except Exception:
        return "nogit"


def load(name: str) -> Prompt:
    path = PROMPTS_DIR / f"{name}.yaml"
    data = yaml.safe_load(path.read_text())
    return Prompt(
        name=data["name"],
        version=int(data["version"]),
        template=data["template"],
        model=data.get("model", ""),
        temperature=float(data.get("temperature", 0.0)),
        git_sha=_git_sha(),
    )
