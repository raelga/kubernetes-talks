# Kubernetes deployment strategies

Kubernetes supports several release patterns. Choose a strategy based on the
amount of additional capacity, traffic control, and operational risk that the
workload can tolerate.

1. [Recreate](01-recreate/): stop the old version before starting the new one.
2. [Ramped](02-ramped/): replace instances gradually with a rolling update.
3. [Blue/green](03-blue-green/): run both versions, then switch traffic.
4. [Canary](04-canary/): expose a small share of traffic to the new version
   before promotion.
5. [A/B testing](05-ab-testing/): route selected requests by weight or request
   attributes.
6. [Shadow](06-shadow/): mirror requests to the new version without using its
   response.

![Deployment strategy decision diagram](decision-diagram.png)

## Prerequisites and controller scope

Use either an EKS cluster or a Kind cluster with a current `kubectl`, Helm 3,
and `curl`. Confirm the selected context before applying a scenario:

```bash
kubectl config current-context
kubectl get nodes
```

The ingress-nginx and Istio installations used by some scenarios are
cluster-level, shared infrastructure. Install each once when its guide asks for
it. Scenario cleanup removes only scenario workloads or namespaces and leaves
those shared components available for the other labs. The Istio canary HPA also
requires metrics-server in the cluster.

On EKS, the control-plane security group must reach the node security group on TCP `15017` for Istio's sidecar-injection webhook. The AWS Academy Terraform stack in this repository manages that rule through `node_security_group_additional_rules`; add an equivalent rule when using another EKS stack.

## Optional Prometheus and Grafana visualization

Run these commands from this directory. Prometheus persistence requires a
default StorageClass, so verify it first:

```bash
kubectl get storageclass
```

Kind normally reports `standard` as `(default)` and needs no change. In the AWS
Academy EKS stack, `gp2` exists but may not be the default; make it the default
before installing Prometheus:

```bash
kubectl annotate storageclass gp2 \
  storageclass.kubernetes.io/is-default-class=true --overwrite
```

Install Prometheus and the Grafana Operator, then apply this lab's resources:

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace --wait

helm upgrade --install grafana-operator \
  oci://ghcr.io/grafana-operator/helm-charts/grafana-operator \
  --namespace monitoring --version v5.0.0 --wait

kubectl apply -f 00-monitoring/grafana.yaml
kubectl apply -f 00-monitoring/deployments-dashboard.yaml
kubectl rollout status deployment/grafana-deployment -n monitoring --timeout=5m
```

### Access Grafana on EKS

Wait until the service has a load-balancer hostname, then open the printed URL:

```bash
kubectl get service grafana-service -n monitoring -w
export GRAFANA_HOST="$(kubectl get service grafana-service -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "http://${GRAFANA_HOST}"
```

### Access Grafana on Kind

Keep this command running and open <http://127.0.0.1:3000>:

```bash
kubectl port-forward service/grafana-service -n monitoring 3000:80
```

Sign in with username `admin` and password `admin`.

## Example dashboards

- [Recreate](01-recreate/grafana-recreate.png)
- [Ramped](02-ramped/grafana-ramped.png)
- [Blue/green](03-blue-green/grafana-blue-green.png)
- [Canary](04-canary/grafana-canary.png)
- [A/B testing](05-ab-testing/grafana-ab-testing.png)
- [Shadow](06-shadow/grafana-shadow.png)
