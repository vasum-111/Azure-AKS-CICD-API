#!/usr/bin/env bash
set -euo pipefail
[[ "${AZURE_COST_APPROVED:-}" == "yes" ]] || { echo 'Stop: set AZURE_COST_APPROVED=yes only after approving the resource plan and Azure charges.' >&2; exit 2; }
: "${AZURE_SUBSCRIPTION_ID:?Set the approved Azure subscription ID}"
: "${RESOURCE_GROUP:?Set a dedicated portfolio resource group}"
LOCATION="${LOCATION:-eastus}"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

: "${AKS_ADMIN_GROUP_ID:?Set an existing Entra administrator group object ID}"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --tags project=azure-aks-cicd-api environment=portfolio >/dev/null
az deployment group create -g "$RESOURCE_GROUP" -n foundation -f infra/main.bicep -p prefix=inventory adminGroupId="$AKS_ADMIN_GROUP_ID" >/dev/null
az deployment group show -g "$RESOURCE_GROUP" -n foundation --query properties.outputs -o json
