### Deploy the Kubernetes Dashboard

Fetch all kubernetes yamls from Github and apply them
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

```
kubectl patch -n kubernetes-dashboard service kubernetes-dashboard -p '{"spec":{"type":"LoadBalancer"}}'
```

### Access the Kubernetes Dashboard


```
export APP_URL=$(kubectl get -n kubernetes-dashboard svc kubernetes-dashboard \
    -o jsonpath="{.status.loadBalancer.ingress[*]['hostname']}") && \
    echo https://${APP_URL}/
while true; do curl -I ${APP_URL}; sleep 5; done;
echo ${APP_URL}
```

### Create a service account to access the dashboard

```
kubectl describe clusterrole cluster-admin
```

```
kubectl apply -n kubernetes-dashboard -f cluster-admin-dashboard-rbac.yaml
```

```
kubectl describe secret -n kubernetes-dashboard $(kubectl get secret -n kubernetes-dashboard | awk '/^cluster-admin-dashboard-token-/{print $1}') | awk '$1=="token:"{print $2}'
```

### Deploy Guestbook app using kubectl

```
kubectl apply -f https://raw.githubusercontent.com/raelga/kubernetes-talks/gb/guestbook.yaml
```

```
kubectl get svc -w
```
