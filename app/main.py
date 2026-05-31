"""FastAPI serving layer: /healthz /chat /metrics.

TODO(step_01_task07): wire /chat to app.agent; TODO(step_06_task01): /metrics.
"""
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="llmops-aks-platform")


class ChatRequest(BaseModel):
    question: str


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.post("/chat")
def chat(req: ChatRequest) -> dict:
    # TODO(step_01_task07): return app.agent.answer(req.question)
    raise NotImplementedError
