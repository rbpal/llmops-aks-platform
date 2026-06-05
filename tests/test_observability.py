from app.observability import metrics


def test_count_tokens():
    assert metrics.count_tokens("hello world") > 0


def test_record_and_metrics_endpoint():
    from fastapi.testclient import TestClient

    import app.rag.ingest as ing
    from app.agent import answer
    from app.main import app

    ing.ingest("data/corpus")
    before = metrics.cost_usd.labels("azure_openai", "gpt-4.1-mini")._value.get()
    answer("What is the capitalization threshold for depreciation?")
    after = metrics.cost_usd.labels("azure_openai", "gpt-4.1-mini")._value.get()
    assert after >= before
    body = TestClient(app).get("/metrics").text
    assert "llm_tokens_in_total" in body and "chat_latency_seconds" in body
