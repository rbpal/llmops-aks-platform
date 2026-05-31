"""Foundry smoke test (step_00_task03): live Azure OpenAI chat + embeddings.
Needs .env filled and USE_STUB_LLM=false.  uv run python scripts/smoke_foundry.py
"""
from __future__ import annotations

import sys

from app.config import settings
from app.llm.client import AzureOpenAIClient


def main() -> int:
    if settings.use_stub_llm:
        print("USE_STUB_LLM=true — set it false in .env to hit real Foundry.")
        return 1
    client = AzureOpenAIClient()
    chat = client.chat(system="You are a test.", user="Reply with the single word: ok")
    print(f"chat[{settings.chat_deployment}] -> {chat!r}")
    vec = client.embed("capitalization threshold")
    print(f"embed[{settings.embedding_deployment}] -> vector length {len(vec)}")
    assert chat and len(vec) > 0
    print("FOUNDRY SMOKE: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
