### Deploy the Kubernetes Dashboard

Fetch all kubernetes yamls from Github and apply them
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

```
kubectl patch -n kubernetes-dashboard service kubernetes-dashboard -p '{"spec":{"type":"LoadBalancer"}}'
```

### Access the Kubernetes Dashboard

On cloud clusters, the `LoadBalancer` service can get an external hostname or IP:

```sh
kubectl get -n kubernetes-dashboard svc kubernetes-dashboard
```

On Kind, use a port-forward instead:

```sh
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443
```

Then open <https://localhost:8443/>.


### Create a service account to access the dashboard

```
kubectl describe clusterrole cluster-admin
```

```
kubectl apply -n kubernetes-dashboard -f cluster-admin-dashboard-rbac.yaml
```

```sh
kubectl -n kubernetes-dashboard get secret cluster-admin-dashboard-token \
  -o jsonpath='{.data.token}' | base64 -d
```

### Deploy Guestbook app using kubectl

```
kubectl apply -f https://raw.githubusercontent.com/raelga/kubernetes-talks/gb/guestbook.yaml
```

```
kubectl get svc -w
```
