import yaml

import app.agent as agent_mod
from eval.run_eval import gate, run

THRESHOLDS = yaml.safe_load(open("eval/thresholds.yaml"))


def _ingest():
    import app.rag.ingest as ing
    ing.ingest("data/corpus")


def test_gate_passes_clean():
    _ingest()
    assert gate(run(), THRESHOLDS) == []


def test_gate_catches_regression(monkeypatch):
    _ingest()
    monkeypatch.setattr(agent_mod, "domain_guard", lambda q: True)
    breaches = gate(run(), THRESHOLDS)
    assert any("off_topic_block" in b for b in breaches), breaches
