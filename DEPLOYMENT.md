# Deploy the containerized API

## Authorization and prerequisites

No Azure resources were created while preparing this repository. Before running a deployment, approve the **subscription, region, resource group, service SKUs, expected runtime and spending limit**. Use a dedicated resource group per project and review the Azure pricing calculator. Budgets notify; they do not automatically cap spending.

Use an authenticated Bash environment with Azure CLI, Bicep, Node.js 24, npm and (for AKS) Docker, kubectl, kubelogin and envsubst. Azure Cloud Shell can run infrastructure commands, but does not provide a local Docker daemon for the release script; run releases on a Docker-capable workstation or GitHub Actions after setup. These templates target Azure public cloud. The initial operator needs resource creation permission plus permission to assign the scoped roles in Bicep. AKS requires an existing Entra administrator group and sufficient VM quota.

~~~bash
az login
export AZURE_SUBSCRIPTION_ID='<approved-subscription-id>'
export RESOURCE_GROUP='<dedicated-project-resource-group>'
export LOCATION=eastus
# Set this only after reviewing/approving the resource plan and charges.
export AZURE_COST_APPROVED=yes
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
~~~

Register the resource providers required by this project if your subscription does not already have them registered. This is an administrator setup action. Read the actual what-if before creating resources.


## Resource plan

AKS Free control-plane tier with one Standard_D2s_v5 node, AzureLinux system pool, Basic ACR, VNet, managed identities, scoped network/AcrPull roles, outbound Standard Load Balancer and public egress IP. The **node VM, disk, registry and networking are billable**, despite the AKS control-plane tier name. Two API replicas share that one node; this is not node-level high availability.

## 1. Create infrastructure

~~~bash
export AKS_ADMIN_GROUP_ID='<existing-entra-group-object-id>'
az group create -n "$RESOURCE_GROUP" -l "$LOCATION"
az deployment group what-if -g "$RESOURCE_GROUP" -f infra/main.bicep -p prefix=inventory adminGroupId="$AKS_ADMIN_GROUP_ID"
bash scripts/deploy-infra.sh
~~~

## 2. Build and release

Run as the approved cluster administrator for the first release, with registry push permission. The release uses a temporary kubeconfig and leaves your existing context unchanged.

~~~bash
export IMAGE_TAG=$(git rev-parse HEAD)
bash scripts/release.sh
~~~

## 3. Test the deployed API

Fetch credentials into a separate temporary kubeconfig, convert the Entra login, then port-forward:

~~~bash
export KUBECONFIG=$(mktemp)
AKS=$(az deployment group show -g "$RESOURCE_GROUP" -n foundation --query properties.outputs.aksName.value -o tsv)
az aks get-credentials -g "$RESOURCE_GROUP" -n "$AKS" --file "$KUBECONFIG"
kubelogin convert-kubeconfig -l azurecli
kubectl -n portfolio port-forward svc/inventory 8080:80
~~~

Open http://localhost:8080 and use the explorer. Verify /healthz, /readyz, /api/products and the missing-product 404.

For an explicitly approved temporary **public HTTP demo**, change the Service type to LoadBalancer with kubectl patch, then get its external IP. This creates billable network resources and exposes the read-only catalog. Do not send credentials or sensitive data over it. For a lasting HTTPS site, provision a domain/certificate and supported TLS gateway, or use the Front Door Premium/private-origin pattern in the commerce repository. Public ingress is not silently enabled by the release workflow.

~~~bash
# Optional; run only after approving public exposure and its costs.
kubectl -n portfolio patch service inventory -p '{"spec":{"type":"LoadBalancer"}}'
kubectl -n portfolio get service inventory
~~~

## GitHub Actions release identity

After initial infrastructure/bootstrap succeeds, create or select an approved Entra application or managed identity for deployment. Configure a federated credential with issuer **https://token.actions.githubusercontent.com**, audience **api://AzureADTokenExchange**, and subject **repo:vasum-111/REPOSITORY:environment:azure-production** (replace REPOSITORY with this repo name). Do not create a long-lived client secret.

Create a GitHub environment named **azure-production**, limit deployments to main, and add a required reviewer where the account supports it. Set environment variables AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID and RESOURCE_GROUP. The release identity needs Reader on the project resource group (deployment outputs), AcrPush on the registry, AKS Cluster User Role on the cluster, and Azure Kubernetes Service RBAC Writer scoped to the portfolio namespace. A cluster administrator must create that namespace and its policy/ServiceAccount first. Bootstrap jobs need access to the existing commerce-config Secret in the commerce project. If applying cluster-scoped namespace manifests, that action stays with the administrator; the release script checks for the existing namespace.

Run **Deploy approved Azure release** from main and type DEPLOY. It runs tests, exchanges an OIDC token, builds/pushes the image and waits for rollout. Infrastructure creation is intentionally a separate operator step. A successful workflow is not a substitute for endpoint smoke testing.

