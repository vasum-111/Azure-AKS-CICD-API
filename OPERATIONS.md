# Operations, tradeoffs and interview notes

## Explain the design

ACR stores release artifacts and AKS runs them. Liveness checks the process; readiness checks whether the app can serve requests. A failed rollout leaves the prior healthy replicas running. OIDC eliminates a stored cloud client secret.

## Observe and troubleshoot

- Start with kubectl -n portfolio get pods, describe pod, logs deployment/inventory and get events --sort-by=.lastTimestamp.
- ImagePullBackOff: check the ACR image digest and kubelet AcrPull assignment.
- Failed readiness: inspect the data connection and dependencies, not just the liveness result.
- Failed bootstrap: inspect the commerce-seed Job logs; check private DNS, workload federation and role propagation.
- Responses carry X-Request-ID; server failures log the ID and error class without connection strings.

Log Analytics export, diagnostic retention and alert rules are **not provisioned**. Enable them after deciding a retention period and budget. Suggested signals: Front Door 5xx/origin health, WAF blocks, AKS unavailable replicas/restarts, SQL connectivity and Redis errors. Avoid logging secrets or full checkout bodies.

## Rollback

For an application-only regression, use kubectl -n portfolio rollout undo deployment/inventory and wait for rollout status. Retain prior ACR digests. SQL migrations are additive in this demo; application rollback is not database rollback. Take database backups and design reversible migration plans before schema changes.

## Production gaps

One node, no node autoscaler, internal API by default, no API authentication and no TLS gateway. The catalog is read-only and intentionally stored in the image. The Kubernetes API endpoint uses Entra/RBAC but is not a private cluster. Network policy limits inbound ports, not application authentication or outbound destinations.

## Cost control and cleanup

Use a dedicated resource group with project/environment tags and create a Cost Management budget before deployment. Review costs daily while learning. Stop or remove unused labs; a stopped app does not stop Front Door, registry, storage or database charges.

After exporting anything you want to keep, inspect the exact resource group:

~~~bash
az resource list --resource-group "$RESOURCE_GROUP" --output table
# Destructive: run only when you intend to remove this entire dedicated lab.
az group delete --name "$RESOURCE_GROUP"
~~~

Check that AKS-managed node resources are removed and inspect remaining resources in the subscription. Retain billing records and verify no orphaned resources remain. Removing a GitHub repository does not remove Azure resources.
