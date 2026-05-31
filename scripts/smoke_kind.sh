#!/usr/bin/env bash
# Local cluster smoke test (step_00_task04): a hello container reaches Running on kind.
set -euo pipefail
CLUSTER="${CLUSTER:-llmops-smoke}"
command -v kind >/dev/null    || { echo "install kind: brew install kind"; exit 1; }
command -v kubectl >/dev/null || { echo "install kubectl: brew install kubectl"; exit 1; }
echo "==> creating kind cluster '$CLUSTER'"
kind create cluster --name "$CLUSTER" --config deploy/kind-config.yaml
echo "==> running hello pod"
kubectl run hello --image=nginxdemos/hello --restart=Never
kubectl wait --for=condition=Ready pod/hello --timeout=120s
kubectl get pod hello -o wide
echo "==> cleanup"
kubectl delete pod hello --ignore-not-found
kind delete cluster --name "$CLUSTER"
echo "KIND SMOKE: OK"
