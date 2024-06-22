
### Install Grafana

```
helm upgrade -i grafana-operator oci://ghcr.io/grafana-operator/helm-charts/grafana-operator --namespace monitoring --version v5.0.0
```

### Review Grafana Custom Resource Definition

```
k describe crd grafanas.grafana.integreatly.org
```

### Setup Grafana

Now that Prometheus and Grafana are up and running, you can access Grafana:

```
kubectl apply -f 00-grafana --namespace monitoring
```

Wait for the load balancer to be provisioned:

```
kubectl get svc -n monitoring grafana-service -w
```

```
echo "http://$(kubectl get svc -n monitoring grafana-service \
    -o jsonpath="{.status.loadBalancer.ingress[*]['hostname']}")"
```

To login, username: `admin`, password: `admin`.


### Fetch some dashboards

https://grafana.com/grafana/dashboards/7249-kubernetes-cluster/