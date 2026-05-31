"""Embed the query and retrieve top-k chunks (step_01_task04). No backend branching."""
from app.llm.client import get_client
from app.rag.store import get_store


def retrieve(question: str, k: int = 4) -> list[dict]:
    vector = get_client().embed(question)
    return get_store().search(vector, k=k)
