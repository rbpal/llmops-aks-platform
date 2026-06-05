"""FastAPI serving layer (step_01_task07): /healthz /chat /metrics."""
from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from pydantic import BaseModel

from app.agent import answer
from app.config import settings

app = FastAPI(title="llmops-aks-platform")

# Paths reachable without an X-Azure-FDID header: the App Gateway backend health probe and the
# in-cluster Prometheus scrape both hit the pod directly (not via Front Door), so enforcing the
# FDID on them would fail the probe / drop metrics. Everything else (i.e. /chat) is gated.
_FDID_EXEMPT = {"/healthz", "/metrics"}


@app.middleware("http")
async def enforce_front_door_origin(request: Request, call_next):
    """Option C, defense-in-depth: when EXPECTED_FDID is set, reject any request that didn't come
    through OUR Front Door (matching the App Gateway WAF rule). No-op when unset (local/dev/CI)."""
    if settings.expected_fdid and request.url.path not in _FDID_EXEMPT:
        fdid = request.headers.get("x-azure-fdid", "")
        if fdid.lower() != settings.expected_fdid.lower():
            return JSONResponse(
                {"detail": "forbidden: request did not arrive via Front Door"},
                status_code=403,
            )
    return await call_next(request)


class ChatRequest(BaseModel):
    question: str


class ChatResponse(BaseModel):
    answer: str
    sources: list[str]
    prompt: str | None = None
    provider: str | None = None
    region: str | None = None  # which region served this (active-active proof)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "region": settings.region}


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest) -> ChatResponse:
    return ChatResponse(region=settings.region, **answer(req.question))


@app.get("/metrics")
def metrics() -> PlainTextResponse:
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)
