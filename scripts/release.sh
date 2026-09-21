#!/usr/bin/env bash
set -euo pipefail
[[ "${AZURE_COST_APPROVED:-}" == "yes" ]] || { echo 'Stop: set AZURE_COST_APPROVED=yes only after approving the resource plan and Azure charges.' >&2; exit 2; }
: "${AZURE_SUBSCRIPTION_ID:?Set the approved Azure subscription ID}"
: "${RESOURCE_GROUP:?Set a dedicated portfolio resource group}"
LOCATION="${LOCATION:-eastus}"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

: "${IMAGE_TAG:?Set an immutable commit SHA or unique release tag}"
get_output() { az deployment group show -g "$RESOURCE_GROUP" -n foundation --query "properties.outputs.$1.value" -o tsv; }
AKS=$(get_output aksName); ACR=$(get_output acrName); LOGIN=$(get_output acrLoginServer)
az acr login -n "$ACR"
export IMAGE="$LOGIN/inventory:$IMAGE_TAG"
docker build -t "$IMAGE" .
docker push "$IMAGE"
DIGEST=$(az acr repository show -n "$ACR" --image "inventory:$IMAGE_TAG" --query digest -o tsv)
export IMAGE="$LOGIN/inventory@$DIGEST"
# Use a temporary context so a user's existing kubeconfig is not overwritten.
export KUBECONFIG; KUBECONFIG=$(mktemp); trap 'rm -f "$KUBECONFIG"' EXIT
az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS" --file "$KUBECONFIG"
kubelogin convert-kubeconfig -l azurecli
kubectl -n portfolio get serviceaccount default >/dev/null 2>&1 || kubectl apply -f k8s/namespace.yaml
envsubst '$IMAGE' < k8s/app.yaml | kubectl apply -f -
kubectl apply -f k8s/network-policy.yaml
kubectl -n portfolio rollout status deployment/inventory --timeout=300s
echo 'API is internal. Test with: kubectl -n portfolio port-forward svc/inventory 8080:80'
