# One target per build step. `make help` lists them.
.DEFAULT_GOAL := help
UV ?= uv

help: ## list targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*?## "}{printf "  %-16s %s\n",$$1,$$2}'

venv: ## step_00_task01 — create .venv + install deps (uv sync)
	$(UV) sync --extra dev

smoke-foundry: ## step_00_task03 — Azure OpenAI chat + embeddings smoke test
	$(UV) run python scripts/smoke_foundry.py

smoke-kind: ## step_00_task04 — hello container on kind
	bash scripts/smoke_kind.sh

ingest: ## step_01_task05 — chunk -> tokenize PII -> embed -> upsert
	$(UV) run python -m app.rag.ingest

run: ## step_01_task07 — run the API locally
	$(UV) run uvicorn app.main:app --reload --port 8000

eval: ## step_04 — run the eval gate (nonzero exit blocks deploy)
	$(UV) run python eval/run_eval.py

build: ## step_03_task01 — build the amd64 image
	docker build -t llmops-genai:local .

up-local: ## step_03_task03 — deploy to kind (dev/test/prod namespaces)
	@echo "TODO(step_03_task03): kubectl apply -k deploy/overlays/{dev,test,prod}"

up-aks: ## step_07_task01 — terraform apply (REAL Azure resources)
	cd infra && terraform apply -var-file=terraform.tfvars

down-aks: ## step_08_task03 — terraform destroy (protect the budget)
	cd infra && terraform destroy -var-file=terraform.tfvars

.PHONY: help venv smoke-foundry smoke-kind ingest run eval build up-local up-aks down-aks
