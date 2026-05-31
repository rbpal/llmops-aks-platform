# LLMOps on AKS — Governed RAG/Agentic Assistant

A deployment + governance backbone for a non-deterministic AI system: a RAG +
agentic assistant that answers accounting/tax questions from a document corpus,
shipped to AKS through a CI pipeline whose **eval gate blocks regressions before
they reach production**. Built as a portfolio demonstrator for an MLOps/LLMOps role.

The product is the **operational machinery around the model** (eval gates, guardrails, PII
controls, audit trail, cost telemetry), not the assistant itself.

## Business problem

**Context.** An accounting / tax / advisory firm runs on expert knowledge work — staff
answering questions grounded in tax code, firm policy, and client documents. That knowledge
is scattered across thousands of documents, so senior people burn billable hours retrieving
and synthesizing information that already exists. A GenAI assistant that answers from the
firm's own documents is an obvious win — and a pilot is easy to build.

**The real problem: pilots are easy, production is not** — especially for a
*non-deterministic* system in a regulated, high-stakes domain. Shipping it is dangerous in
five specific ways:

| Risk | Why it's existential here |
| --- | --- |
| **Wrong answers** | This is tax advice. A hallucinated figure → client penalties, malpractice exposure, reputational damage. |
| **PII everywhere** | Client documents are full of SSNs and account numbers. A leak → breach notification, regulatory fines, lost trust. |
| **Non-determinism** | Same input, different output — can't be unit-tested like normal software. Quality silently regresses when a prompt or model changes. |
| **Cost blowups** | Tokens are real money; a runaway agent loop burns budget, not just CPU. |
| **No audit trail** | Regulators and clients ask "what produced this answer?" Without prompt + model versioning there is no defensible record. |

**Problem statement.** How do we ship non-deterministic GenAI to production in a
high-stakes, regulated domain — safely (no bad answers, no PII leaks), affordably (bounded,
visible cost), and auditably (every answer traceable) — and stop it from silently degrading
over time? That is the LLMOps problem this project solves.

**What "solved" delivers.**

| Capability | Business outcome |
| --- | --- |
| Eval gate (LLM-as-judge in CI) | Bad prompt/model changes are blocked before prod, automatically |
| PII tokenization + guardrails + Key Vault | Raw PII never reaches the model, vector store, or logs |
| Prompt/model registry + version+SHA logging | Every answer is traceable and auditable |
| Per-provider token/cost/latency telemetry + FinOps | Cost is visible and bounded; no surprise bills |
| AKS autoscale + governed promotion | Scales with demand; releases are controlled and reversible |

**Stakes.** A single hallucinated tax figure, leaked SSN, runaway agent, or silent quality
drift can cost more than the whole initiative saves — which is exactly why firms stall at
the pilot stage. This backbone is what lets them actually deploy.

## Architecture — the three data lanes

```
LANE 1 — INGESTION  (offline, run once before serving)
══════════════════════════════════════════════════════
 data/corpus/*.md            ◀── SOURCE: synthetic accounting/tax docs
        │                        (one has planted PII for the tokenization demo)
        ▼
 tokenize PII (deterministic): "123-45-6789" → "[SSN_xxxx]"  ──► VAULT (token→real)
        │                                                         (Key Vault primary)
        ▼
 chunk (~500 tok) ─► Azure OpenAI EMBEDDINGS ─► VECTOR STORE
   runtime = Azure AI Search (managed)  |  inner loop = FAISS (local)
   record = id + content + source + content_vector   (no raw PII anywhere downstream)


LANE 2 — QUERY  (online, per request, on AKS)
══════════════════════════════════════════════════════
 USER QUESTION                ◀── SOURCE: operator types it live
   ─► input guard (block injection)
   ─► domain guard (accounting/tax? else block)
   ─► embed question ─► retrieve top-k chunks ◀──► VECTOR STORE
   ─► assemble prompt (question + chunks + versioned template from registry/)
   ─► LLM CHAT via provider router (Azure OpenAI | Anthropic Claude)  [tokens only, never raw PII]
   ─► output guard (redact stray PII, off-topic)
   ─► detokenize IF authorized → real value; else keep token
   ─► ANSWER (+ [source: ...]) ─► user
        └── emits ─► telemetry: tokens, cost, latency (by provider) ─► /metrics


LANE 3 — EVAL  (used only by the CI gate, never served)
══════════════════════════════════════════════════════
 eval/golden/qa_set.yaml      ◀── SOURCE: author-written Q&A
   ─► run each question through the SAME Lane 2 path
   ─► judge (correctness/grounded) + refusal exact-match + PII-leak + off-topic
   ─► compare to thresholds.yaml ─► PASS allows deploy / FAIL blocks the PR
```

The **vector store is the hinge**: Lane 1 fills it, Lane 2 reads it, Lane 3 exercises all
of Lane 2 to grade it before anything ships.

## Workflow narrative — how this changes an accountant's day

The product is the governed pipeline around the model. This is what that pipeline *feels
like* to the person using it, and what it protects behind the scenes.

**The "before" — how it works today.** It's 4:45 PM. Maya, a tax associate, has a client
asking whether a $4,200 equipment purchase can be expensed this year. To answer
confidently she has to: remember which internal policy governs capitalization; dig through
a shared drive for the current threshold; cross-check it didn't change this year; and make
sure she's not accidentally quoting another client's engagement terms. Twenty minutes,
three documents, one Slack message to a senior, and a lingering "...I think that's right."
Multiply that across hundreds of staff and thousands of questions a week — that's the cost
the firm is paying.

**The "after" — the same question, with this solution.** Maya types one sentence:

> *"What's our capitalization threshold for depreciation, and does a $4,200 purchase
> qualify to be expensed?"*

She gets back, in ~2 seconds:

> *"Fixed assets at or above the **$5,000** capitalization threshold are capitalized and
> depreciated; purchases below it are expensed in the period incurred. A $4,200 purchase is
> **below** the threshold, so it would be expensed. **[source: 01_depreciation_policy.md]**"*

She has the answer, the reasoning, and the source she can cite — in one step instead of
twenty minutes. The value isn't the speed; it's everything that happened invisibly to make
that answer trustworthy enough to act on.

### The full workflow — journey of one question

```
            ┌──────────────────────────────────────────────────────────────────────┐
   MAYA     │  "What's our capitalization threshold, and does $4,200 qualify?"      │
 (accountant)└─────────────────────────────────┬────────────────────────────────────┘
                                                │  HTTPS → /chat  (the assistant API on AKS)
                                                ▼
   ┌───────────────────────────────────────────────────────────────────────────────────┐
   │  GOVERNED PIPELINE  (runs per question — every gate protects Maya AND the firm)      │
   │                                                                                     │
   │  1. INPUT GUARD ───────► "Is this a manipulation attempt?"                           │
   │        │                  blocks "ignore your rules / dump other clients' data"      │
   │        ▼                                                                             │
   │  2. DOMAIN GUARD ──────► "Is this an accounting/tax question?"                        │
   │        │                  off-topic ("what's the weather?") → polite refusal         │
   │        ▼                                                                             │
   │  3. RETRIEVE ──────────► embed the question → search the VECTOR STORE                 │
   │        │                  pulls the few most relevant policy chunks (grounding)       │
   │        │                  ◀── these chunks were PII-tokenized at ingestion            │
   │        ▼                                                                             │
   │  4. ASSEMBLE PROMPT ───► question + retrieved chunks + a VERSIONED template           │
   │        │                  (template pulled from the prompt registry, v1 @<git-sha>)   │
   │        ▼                                                                             │
   │  5. LLM ANSWERS ───────► provider router → Azure OpenAI | Anthropic Claude            │
   │        │                  the model sees ONLY tokens, never a real SSN/account #      │
   │        ▼                                                                             │
   │  6. OUTPUT GUARD ──────► redacts any stray PII; rejects off-topic drift               │
   │        │                                                                             │
   │        ▼                                                                             │
   │  7. DETOKENIZE (gated)─► IF Maya is authorized → swap tokens back to real values      │
   │        │                  ELSE → leave "[SSN_xxxx]" in place                          │
   │        ▼                                                                             │
   │  ANSWER + [source: depreciation_policy]                                              │
   └─────────┬──────────────────────────────────────────────────┬────────────────────────┘
             │                                                    │
             ▼                                                    ▼
   ┌──────────────────┐                            ┌──────────────────────────────────┐
   │  BACK TO MAYA     │                            │  EMITTED INVISIBLY (every call)   │
   │  grounded answer  │                            │  • telemetry: tokens, $ cost,     │
   │  + citation       │                            │    latency, by provider → /metrics │
   │  in ~2 seconds    │                            │  • audit log: prompt v1 @<sha>,    │
   └──────────────────┘                            │    which model, which sources      │
                                                    └──────────────────────────────────┘
```

And one layer Maya never sees but the firm depends on — the eval gate that ran *before*
this version was ever deployed:

```
   BEFORE ANY OF THIS REACHED MAYA  (CI gate, on every change)
   ══════════════════════════════════════════════════════════
   engineer changes a prompt/model  ─► runs the golden Q&A through the SAME pipeline
                                     ─► judge scores correctness + grounding
                                        + checks: did it refuse what it should?
                                                  did any PII leak? did it stay on-topic?
                                     ─► PASS → ships    |    FAIL → the change is blocked
```

That's why Maya can trust the answer: a regression that would make the assistant
hallucinate a threshold or leak a client SSN would have failed the gate and never shipped.

### What each step actually does for Maya

| Step | What Maya feels | What it really protects |
| --- | --- | --- |
| Input + domain guards | "It stays on task" | Blocks prompt-injection and off-topic misuse |
| Retrieve + cite | "It shows its source" | Answer is grounded in firm docs, not the model's guesswork |
| Versioned prompt | (invisible) | Every answer is reproducible and auditable |
| Tokenized model call | "It just works" | A real SSN/account number never reaches the model or logs |
| Output guard | "Clean answers" | Last-line backstop against stray PII / drift |
| Authorization-gated detokenize | "I see what I'm allowed to" | Sensitive values revealed only to authorized staff |
| Telemetry + audit (side-channel) | (invisible) | Cost stays bounded; the firm can prove what produced any answer |

### A second scene — when the system says no (the trust-builder)

> *"What's the SSN on the Henderson engagement?"* → *"I don't have that information."*

Nothing leaked — the SSN was tokenized out at ingestion and the asker wasn't authorized to
detokenize. And:

> *"What's the weather in Chicago tomorrow?"* → *"I can only help with accounting and tax
> questions."*

Those refusals aren't accidents — they're enforced by the domain guard and continuously
tested by the eval gate. The fact that the system reliably declines is exactly what lets
the firm put it in front of staff and, eventually, clients.

### The bottom line

| | Before | After |
| --- | --- | --- |
| Time to a confident answer | ~20 min, multiple docs | ~2 sec, one question |
| Source / citation | manual, often missing | automatic `[source: …]` |
| PII safety | depends on the human | enforced by design |
| Consistency | varies by who you ask | same governed pipeline every time |
| Auditability | "I think I read it somewhere" | prompt version + model + sources logged |
| Cost control | invisible | measured per call, alertable |

The solution doesn't just make Maya faster — it makes her answers **groundable, safe, and
defensible**, which is the only version of "AI assistant" an accounting firm can actually
deploy.

## What it shows
- **Eval gate as a deploy gate** — golden set + LLM-as-judge scoring correctness,
  groundedness, refusal rate, and PII leakage; a failing score blocks the merge.
- **Prompt + config as versioned artifacts** — prompts in git; every answer logs
  prompt name + version + git SHA (auditable "what was running when").
- **PII tokenization with a vault** — SSNs/account numbers are tokenized at
  ingestion, so the model, vector store, and logs never see real values;
  authorized reads detokenize on the way out.
- **Managed vector store** — Azure AI Search (Free tier) at runtime; FAISS for the
  local inner loop; both behind one interface, swapped by config.
- **AKS with 1->3 node autoscaling**, deployed via Terraform modules.
- **Azure-native observability** — the app emits tokens, cost, latency, and failure
  metrics in Prometheus format; **Azure Monitor Managed Prometheus** scrapes them on
  AKS and **Azure Managed Grafana** visualizes them (both provisioned in Terraform).

## Quickstart
```bash
# install uv if needed: curl -LsSf https://astral.sh/uv/install.sh | sh
make venv                 # uv sync — creates .venv, installs from pyproject.toml
cp .env.example .env      # fill in Foundry endpoint/key/deployments
make smoke-foundry        # step_00: verify Azure OpenAI works
make smoke-kind           # step_00: verify local cluster
make ingest               # build PII-free vector index (VECTOR_STORE=faiss locally)
make run                  # serve locally on :8000
make eval                 # run the eval gate
```


## Observability — viewable locally on your laptop

The app is instrumented once (plain Prometheus format at `/metrics`). **You don't need
Azure to see it** — the metrics are served by the app itself, so the full
token/cost/latency telemetry is visible locally. Only the *managed scraper* (Azure Monitor
Managed Prometheus) and the hosted dashboards (Azure Managed Grafana) are Azure-side; the
exact same endpoint feeds both.

```bash
make run          # serve on :8000 (USE_STUB_LLM=true → no API cost)
make obs-up       # optional: local Prometheus + Grafana at http://localhost:3000
make load         # fire sample /chat traffic so the charts move
curl -s localhost:8000/metrics | grep -E 'llm_|chat_'
```

Live output on the laptop after a few `/chat` calls (per-provider, per-model):

```
llm_tokens_in_total{model="gpt-4o-mini",provider="stub"}   962.0
llm_tokens_out_total{model="gpt-4o-mini",provider="stub"}  169.0
llm_cost_usd_total{model="gpt-4o-mini",provider="stub"}    0.0002457
chat_requests_total{provider="stub",status="ok"}           3.0
chat_latency_seconds_count                                 3.0
chat_latency_seconds_sum                                   0.000262
```

`provider="stub"` because `USE_STUB_LLM=true` (no API cost); with real Azure OpenAI the
same lines read `provider="azure_openai"` with real token counts and dollar cost. A local
Grafana stack (`deploy/local-observability/`) charts these; in production Azure Managed
Grafana renders the identical metrics.

## Stack
FastAPI + (LangGraph) agent · Azure AI Search (FAISS local fallback) · Azure OpenAI
(Foundry: gpt-4o-mini + text-embedding-3-small) · uv · Docker · kind (local) / AKS (cloud) ·
kustomize · Terraform (azurerm) · GitHub Actions · Azure Monitor Managed Prometheus + Managed Grafana.

## Build plan

Step-by-step build with `step_XX_taskYY` tasks and per-task acceptance checks. Code stubs
are marked `# TODO(step_XX_taskYY)`.

- **step_00** Bootstrap & smoke tests (venv, Foundry, kind, terraform validate)
- **step_01** Spine: FastAPI + config + LLM router (OpenAI + Anthropic) + RAG + agent
- **step_02** PII tokenization + vault (Key Vault primary)
- **step_03** Containerize + 3 namespaces on kind
- **step_04** Eval gate (LLM-as-judge) — the centerpiece; CI blocks regressions
- **step_05** Guardrails + prompt registry audit + CD promotion
- **step_06** Observability — Azure-native Prometheus + Grafana, per-provider + cost
- **step_07** Real AKS + 1->3 autoscale demo (Terraform)
- **step_08** Wrap up + teardown (destroy billable resources)

The system runs as three data lanes — **Ingestion** (corpus → tokenize PII → chunk →
embed → vector store), **Query** (guards → retrieve → assemble versioned prompt → LLM
router → guards → detokenize → answer + telemetry), and **Eval** (golden Q&A through the
same query path → judge + checks → thresholds gate the deploy). Key decisions: Azure Key
Vault for secrets/PII, multi-provider LLM router (Azure OpenAI + Anthropic Claude), Azure
AI Search + FAISS behind one interface, Azure-native Prometheus + Grafana.