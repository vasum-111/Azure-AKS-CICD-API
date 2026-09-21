# Containerized API with AKS and CI/CD

[![Validate](https://github.com/vasum-111/azure-aks-cicd-api/actions/workflows/ci.yml/badge.svg)](https://github.com/vasum-111/azure-aks-cicd-api/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

A deliberately small API that demonstrates the full path from a tested commit to an observable Kubernetes workload.

**[Open browser preview](https://vasum-111.github.io/azure-aks-cicd-api/)** · **[Deployment guide](DEPLOYMENT.md)** · **[Operations & tradeoffs](OPERATIONS.md)**

> **Deployment status:** the public browser preview is static hosting on GitHub Pages. It uses sample data and does not call an Azure backend. Azure resources have **not** been provisioned; cloud deployment awaits subscription access and cost approval. Bicep compilation and local tests are validation, not evidence of a successful Azure deployment.

## What this demonstrates

- Working inventory API with browser explorer and a read-only product catalog.
- Non-root Node.js container with bounded requests, security headers and graceful shutdown.
- AKS manifests with startup/readiness/liveness probes, resource limits and a disruption budget.
- GitHub Actions tests/builds and an explicitly triggered OIDC release to ACR and AKS.

## Architecture

~~~mermaid
flowchart LR
    Commit[Commit / pull request] --> CI[Tests + container build + Bicep validation]
    Operator[Approved manual release] --> Actions[GitHub Actions / OIDC]
    Actions --> ACR[Azure Container Registry]
    ACR --> AKS[AKS / two API replicas]
    Tester -->|Port-forward| API[ClusterIP service]
    API --> AKS
    AKS --> Catalog[Read-only JSON catalog]
~~~

The cluster service is internal by default. The deployment guide includes local port-forward testing and an optional public demo endpoint. Public TLS ingress is an explicit follow-up choice.

## Run locally

Prerequisite: Node.js 24 LTS and npm.

~~~bash
git clone https://github.com/vasum-111/azure-aks-cicd-api.git
cd azure-aks-cicd-api
npm ci
npm test
npm start
~~~

Open **http://localhost:8080**. No Azure account or database is required for local development.

## API contract

| Method | Route | Behavior |
|---|---|---|
| GET | /api/products | Catalog with integer USD cents |
| GET | /api/products/:id | Product or 404 |
| GET | /healthz | Process liveness |
| GET | /readyz | Data-store readiness |



## Repository map

| Path | Purpose |
|---|---|
| web/ | Original website and interactive UI |
| docs/ | GitHub Pages preview; sample mode enabled |
| infra/ | Bicep resource definitions |
| scripts/ | Explicit deployment helpers |
| src/ | Application and data adapters |
| k8s/ | Deployment, service, probes and policies |
| test/ | Automated checks |
| .github/workflows/ | Continuous validation and gated Azure release |

## Validation and limitations

See [VALIDATION.md](VALIDATION.md) for tested behavior and unverified cloud steps. This is a learning/portfolio project, not a production certification. 

## Specification and attribution

Built from the three-project scope supplied by the user from the **Azure Services Crash Course**. The original PDF attachment was unavailable in this task, so its exact text and resource links could not be checked. The user-provided project names/services are the scope of record. Application code, layout, artwork and project structure are original; no third-party repository was copied. Microsoft documentation informed service configuration. See [REFERENCES.md](REFERENCES.md). MIT license covers this repository; dependencies retain their own licenses.
