"""Prompt registry loader: load yaml by name, expose template/model/temperature,
record current git SHA. TODO(step_01_task03)."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Prompt:
    name: str
    version: int
    template: str
    model: str
    temperature: float
    git_sha: str


def load(name: str) -> Prompt:
    raise NotImplementedError  # TODO(step_01_task03)
